extern crate csv;
#[macro_use]
extern crate failure;
extern crate fake;
extern crate rand;
extern crate serde;
#[macro_use]
extern crate serde_derive;
extern crate serde_yaml;
extern crate chrono;

use std::io;
use std::fs;
use std::cmp;
use std::path::Path;
use zip::ZipWriter;
use zip::write::FileOptions;
use std::io::BufWriter;
use std::io::Cursor;
use std::io::Write;


use crate::errors::DataGenResult;
use crate::schema::Schema;
use crate::sinks::{csv_sink, Sink};

pub mod errors;
pub mod fakegen;
pub mod options;
pub mod schema;
pub mod sinks;
pub mod dataframe;

use rayon::prelude::*;
use rayon::ThreadPoolBuilder;

const DEFAULT_CHUNK_SIZE: i64 = 10_000;

///
/// This program just delegates all the fake data generation work to the wonderful fake-rs library
///
//TODO Need to consider Enum, Union, Fixed, Date, Timestamp and other logical types of Avro too.
#[derive(Debug, PartialEq, Serialize, Clone)]
pub enum DValue {
    Null,
    Boolean(bool),
    Int(i32),
    Long(i64),
    Float(f32),
    Double(f64),
    Bytes(Vec<u8>),
    Str(String),
    Date(String),
    DateTime(String),
    Record(Vec<(String, DValue)>),
}

#[derive(Debug, PartialEq, Deserialize, Serialize, Clone)]
#[serde(rename_all = "lowercase")]
pub enum DType {
    Boolean,
    Int,
    Float,
    Long,
    Double,
    String,
    Age,
    Name,
    City,
    Phone,
    Date,
    DateTime,
    Latitude,
    Longitude,

    //TODO - For now, let's stick to basic types
    //    Date, Array, Map, Nullable (union/null), Record,
}

pub fn write_csv_concurrent(
    output_dir: String,       // Output directory path
    schema_path: String,
    num_records: i64,
    delimiter: u8,
    file_splits: usize,
    _thread_pool_size: usize,
    _zip_pack_batch_size: usize,
) -> DataGenResult<()> {
    let schema = Schema::from_path(schema_path.clone())?;

    let table_name = schema.dataset.name.clone();

    let records_per_file = num_records / file_splits as i64;
    let remainder = num_records % file_splits as i64;

    let _ = fs::create_dir_all(&output_dir)?;
    
    // Use Rayon parallel iterator to distribute file writing across thread pool
    let results: Vec<Result<(), String>> = (0..file_splits)
        .into_par_iter() // Distribute file writing across Rayon pool
        .map(|i| {
                let schema_clone = schema.clone();
                let output_dir_clone = output_dir.clone();
                let table_name_clone = table_name.clone();

                let records_for_this_file = if i == file_splits - 1 {
                    records_per_file + remainder
                } else {
                    records_per_file
                };
                
                // Generate file path with zero-padded index
                let file_path = format!("{}/output_{}_{}_{:02}.csv",
                                       output_dir_clone, table_name_clone, num_records, i);
                
                // Create file and CSV writer
                let file = fs::File::create(&file_path)
                    .map_err(|e| format!("Failed to create file {}: {}", file_path, e))?;
                
                // Clone schema for generation before moving it into sink
                let schema_for_gen = schema_clone.clone();
                
                let mut sink = csv_sink::sink(schema_clone, file, delimiter)
                    .map_err(|e| format!("Failed to create CSV sink for {}: {}", file_path, e))?;
                
                // Generate records in chunks to avoid OOM
                let chunk_size = DEFAULT_CHUNK_SIZE;
                let mut remaining = records_for_this_file;
                
                while remaining > 0 {
                    let batch_size = std::cmp::min(remaining, chunk_size);
                    let records: Vec<DValue> = (0..batch_size)
                        .into_par_iter()
                        .map(|_| fakegen::gen_record_for_schema(schema_for_gen.clone()))
                        .collect();
                    
                    for record in records {
                        sink.write(record)
                            .map_err(|e| format!("Failed to write record to {}: {}", file_path, e))?;
                    }
                    remaining -= batch_size;
                }
                
            Ok(())
        })
        .collect(); // Collect results, waiting for all tasks to complete
    
    // Handle potential errors from parallel execution
    for res in results {
        if let Err(e) = res {
            return Err(errors::DataGenError::WeirdCase { message: e });
        }
    }
    
    // Create ZIP files in batches concurrently
    if _zip_pack_batch_size == 0 {
        // If batch size is 0, create individual ZIP files (current behavior)
        // Use Rayon parallel iterator for concurrent zipping
        let zip_results: Vec<Result<(), String>> = (0..file_splits)
            .into_par_iter() // Distribute zipping across Rayon pool
            .map(|i| {
                let csv_file_path = format!("{}/output_{}_{}_{:02}.csv", output_dir, table_name, num_records, i);
                if Path::new(&csv_file_path).exists() {
                    create_single_csv_zip(&csv_file_path, &output_dir)
                        .map_err(|e| format!("Failed to create ZIP for {}: {}", csv_file_path, e))?;
                    // Delete CSV file after successful ZIP creation
                    let _ = fs::remove_file(&csv_file_path);
                }
                Ok(())
            })
            .collect(); // Collect results, waiting for all ZIP operations to complete
        
        // Handle potential errors from parallel ZIP operations
        for res in zip_results {
            if let Err(e) = res {
                return Err(errors::DataGenError::WeirdCase { message: e });
            }
        }
    } else {
        // Create batched ZIP files concurrently
        let batches: Vec<(usize, usize)> = {
            let mut batches = Vec::new();
            let mut batch_start = 0;
            while batch_start < file_splits {
                let batch_end = std::cmp::min(batch_start + _zip_pack_batch_size, file_splits);
                batches.push((batch_start, batch_end));
                batch_start = batch_end;
            }
            batches
        };
        
        // Use Rayon parallel iterator for concurrent batch zipping
        let zip_results: Vec<Result<(), String>> = batches
            .into_par_iter() // Distribute batch zipping across Rayon pool
            .map(|(batch_start, batch_end)| {
                let csv_files: Vec<String> = (batch_start..batch_end)
                    .map(|i| format!("{}/output_{}_{}_{:02}.csv", output_dir, table_name, num_records, i))
                    .filter(|path| Path::new(path).exists())
                    .collect();
                
                if !csv_files.is_empty() {
                    let start_idx = batch_start;
                    let end_idx = batch_end - 1;
                    let zip_filename = format!("output_{}_{}_{:02}_{:02}.csv.zip", table_name, num_records, start_idx, end_idx);
                    create_batch_csv_zip(&csv_files, &output_dir, &zip_filename)
                        .map_err(|e| format!("Failed to create batch ZIP {}: {}", zip_filename, e))?;
                    
                    // Delete CSV files after successful ZIP creation
                    for csv_file in &csv_files {
                        let _ = fs::remove_file(csv_file);
                    }
                }
                Ok(())
            })
            .collect(); // Collect results, waiting for all batch ZIP operations to complete
        
        // Handle potential errors from parallel batch ZIP operations
        for res in zip_results {
            if let Err(e) = res {
                return Err(errors::DataGenError::WeirdCase { message: e });
            }
        }
    }
    
    Ok(())
}

fn create_single_csv_zip(
    csv_file_path: &str,
    output_dir: &str,
) -> DataGenResult<String> {
    let csv_path = Path::new(csv_file_path);
    let csv_filename = csv_path.file_name()
        .ok_or_else(|| errors::DataGenError::WeirdCase {
            message: format!("Invalid CSV file path: {}", csv_file_path)
        })?
        .to_str()
        .ok_or_else(|| errors::DataGenError::WeirdCase {
            message: format!("Invalid UTF-8 in CSV file path: {}", csv_file_path)
        })?;
    
    let zip_filename = format!("{}.zip", csv_filename);
    let zip_file_path = format!("{}/{}", output_dir, zip_filename);
    
    // Create zip file
    let zip_file = fs::File::create(&zip_file_path)
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to create zip file {}: {}", zip_file_path, e)
        })?;
    println!("zip_file_path:{}",zip_file_path);
    let mut zip = ZipWriter::new(zip_file);
    let options = FileOptions::default()
//        .compression_method(zip::CompressionMethod::Stored)
        .compression_method(zip::CompressionMethod::Deflated)
        // Optional: Set a compression level 0-9(e.g., 9 for best compression)
        .compression_level(Some(9))
        .unix_permissions(0o644);
    
    // Add CSV file to zip
    let mut csv_file = fs::File::open(csv_file_path)
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to open CSV file {}: {}", csv_file_path, e)
        })?;
    
    let mut buffer = Vec::new();
    use std::io::Read;
    csv_file.read_to_end(&mut buffer)
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to read CSV file {}: {}", csv_file_path, e)
        })?;
    
    zip.start_file(csv_filename, options)
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to start zip entry for {}: {}", csv_filename, e)
        })?;
    
    zip.write_all(&buffer)
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to write to zip file {}: {}", zip_file_path, e)
        })?;
    
    zip.finish()
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to finish zip file {}: {}", zip_file_path, e)
        })?;
    
    Ok(zip_file_path)
}

fn create_batch_csv_zip(
    csv_files: &[String],
    output_dir: &str,
    zip_filename: &str,
) -> DataGenResult<String> {
    let zip_file_path = format!("{}/{}", output_dir, zip_filename);
    
    // Create zip file
    let zip_file = fs::File::create(&zip_file_path)
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to create zip file {}: {}", zip_file_path, e)
        })?;
    println!("batch_zip_file_path:{}", zip_file_path);
    let mut zip = ZipWriter::new(zip_file);
    let options = FileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .compression_level(Some(9))
        .unix_permissions(0o644);
    
    // Add each CSV file to the zip
    use std::io::Read;
    for csv_file_path in csv_files {
        let csv_path = Path::new(csv_file_path);
        let csv_filename = csv_path.file_name()
            .ok_or_else(|| errors::DataGenError::WeirdCase {
                message: format!("Invalid CSV file path: {}", csv_file_path)
            })?
            .to_str()
            .ok_or_else(|| errors::DataGenError::WeirdCase {
                message: format!("Invalid UTF-8 in CSV file path: {}", csv_file_path)
            })?;
        
        let mut csv_file = fs::File::open(csv_file_path)
            .map_err(|e| errors::DataGenError::WeirdCase {
                message: format!("Failed to open CSV file {}: {}", csv_file_path, e)
            })?;
        
        let mut buffer = Vec::new();
        csv_file.read_to_end(&mut buffer)
            .map_err(|e| errors::DataGenError::WeirdCase {
                message: format!("Failed to read CSV file {}: {}", csv_file_path, e)
            })?;
        
        zip.start_file(csv_filename, options)
            .map_err(|e| errors::DataGenError::WeirdCase {
                message: format!("Failed to start zip entry for {}: {}", csv_filename, e)
            })?;
        
        zip.write_all(&buffer)
            .map_err(|e| errors::DataGenError::WeirdCase {
                message: format!("Failed to write to zip file {}: {}", zip_file_path, e)
            })?;
    }
    
    zip.finish()
        .map_err(|e| errors::DataGenError::WeirdCase {
            message: format!("Failed to finish zip file {}: {}", zip_file_path, e)
        })?;
    
    Ok(zip_file_path)
}


#[cfg(test)]
mod tests {
    use std::fs;
    use std::fs::File;
    use std::io::{BufRead, BufReader};
    use std::path::Path;

    use serde_json::Value;

    fn get_file_writer(path: &str) -> File {
        fs::create_dir_all(Path::new(path).parent().unwrap()).unwrap();
        let writer = File::create(path).expect("Output File Path not found");
        writer
    }

    #[test]
    fn test_write_csv_concurrent() {
        // Test with 4 splits and batch size 2 (should create 2 ZIP files containing 2 CSVs each)
        let output_dir = "./output_data/concurrent_test";
        let thread_pool_size = 2; // Set pool size to 2, independent of 4 file_splits
        let zip_pack_batch_size = 2; // Test with batch size 2
        super::write_csv_concurrent(
            output_dir.to_string(),
            "./test_data/schema_simple.yaml".to_string(),
            1000,
            ',' as u8,
            4,
            thread_pool_size, // Pass new parameter
            zip_pack_batch_size, // New parameter
        ).unwrap();
        
        // Verify 0 CSV files were created (they should be deleted after ZIP creation)
        let csv_count = (0..4).map(|i| {
            let file_path = format!("{}/output_person_table_1000_{:02}.csv", output_dir, i);
            Path::new(&file_path).exists()
        }).filter(|&exists| exists).count();
        
        assert_eq!(csv_count, 0, "Expected 0 CSV files to remain after ZIP creation");
        
        // Verify 2 batched ZIP files were created (each containing 2 CSV files)
        let zip_files_exist = [
            format!("{}/output_person_table_1000_00_01.csv.zip", output_dir),
            format!("{}/output_person_table_1000_02_03.csv.zip", output_dir),
        ];
        
        for zip_path in &zip_files_exist {
            assert!(Path::new(zip_path).exists(), "Expected ZIP file to exist: {}", zip_path);
        }
        
        // Clean up test files
        for zip_path in &zip_files_exist {
            let _ = fs::remove_file(zip_path);
        }
        let _ = fs::remove_dir(output_dir);
    }

    #[test]
    fn test_write_csv_concurrent_single_batch() {
        // Test with zip_pack_batch_size = 0 (individual ZIP files, not batching)
        let output_dir = "./output_data/single_batch_test";
        let thread_pool_size = 2;
        let zip_pack_batch_size = 0; // Individual ZIP files (not batched)
        super::write_csv_concurrent(
            output_dir.to_string(),
            "./test_data/schema_simple.yaml".to_string(),
            1000,
            ',' as u8,
            4,
            thread_pool_size,
            zip_pack_batch_size,
        ).unwrap();
        
        // Verify 0 CSV files were created (they should be deleted after ZIP creation)
        let csv_count = (0..4).map(|i| {
            let file_path = format!("{}/output_person_table_1000_{:02}.csv", output_dir, i);
            Path::new(&file_path).exists()
        }).filter(|&exists| exists).count();
        
        assert_eq!(csv_count, 0, "Expected 0 CSV files to remain after ZIP creation");
        
        // Verify 4 individual ZIP files were created
        let zip_files_exist: Vec<String> = (0..4).map(|i| {
            format!("{}/output_person_table_1000_{:02}.csv.zip", output_dir, i)
        }).collect();
        
        for zip_path in &zip_files_exist {
            assert!(Path::new(zip_path).exists(), "Expected ZIP file to exist: {}", zip_path);
        }
        
        assert_eq!(zip_files_exist.len(), 4, "Expected 4 individual ZIP output files to be created");
        
        // Clean up test files
        for zip_path in &zip_files_exist {
            let _ = fs::remove_file(zip_path);
        }
        let _ = fs::remove_dir(output_dir);
    }

    #[test]
    fn test_write_csv_many_batches() {
        // Test with multiple batches (batch size 3, 10 files -> 4 batches: 3+3+3+1)
        let output_dir = "./output_data/many_batches_test";
        let thread_pool_size = 2;
        let zip_pack_batch_size = 3; // 4 batches: 3+3+3+1
        super::write_csv_concurrent(
            output_dir.to_string(),
            "./test_data/schema_simple.yaml".to_string(),
            600, // Smaller dataset for faster test
            ',' as u8,
            10,  // 10 file splits
            thread_pool_size,
            zip_pack_batch_size,
        ).unwrap();
        
        // Verify 0 CSV files were created (they should be deleted after ZIP creation)
        let csv_count = (0..10).map(|i| {
            let file_path = format!("{}/output_person_table_600_{:02}.csv", output_dir, i);
            Path::new(&file_path).exists()
        }).filter(|&exists| exists).count();
        
        assert_eq!(csv_count, 0, "Expected 0 CSV files to remain after ZIP creation");
        
        // Verify 4 batched ZIP files were created: 3+3+3+1
        let expected_zip_files = [
            format!("{}/output_person_table_600_00_02.csv.zip", output_dir), // files 0,1,2
            format!("{}/output_person_table_600_03_05.csv.zip", output_dir), // files 3,4,5
            format!("{}/output_person_table_600_06_08.csv.zip", output_dir), // files 6,7,8
            format!("{}/output_person_table_600_09_09.csv.zip", output_dir), // file 9
        ];
        
        for zip_path in &expected_zip_files {
            assert!(Path::new(zip_path).exists(), "Expected ZIP file to exist: {}", zip_path);
        }
        
        // Clean up test files
        for zip_path in &expected_zip_files {
            let _ = fs::remove_file(zip_path);
        }
        let _ = fs::remove_dir(output_dir);
    }
}
