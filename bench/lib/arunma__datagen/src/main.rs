extern crate structopt;

use std::fmt::Error;
use std::fs;
use std::fs::File;

use failure_tools::ok_or_exit;
use structopt::StructOpt;

use datagen::{write_csv_concurrent};
use std::path::Path;
use num_format::{Locale, ToFormattedString};
use chrono::Utc;
use std::time::Instant;

mod options;

fn run() -> Result<(), Error> {
    use options::Command::*;

    let opt: options::Args = options::Args::from_args();

    match opt.command {
        GenerateCSV {
            output_path,
            schema_path,
            num_records,
            delimiter,
            file_splits,
            thread_pool_size,
            zip_pack_batch_size,
        } => {

            let custom_format = Utc::now().format("%Y-%m-%d %H:%M:%S.%3f UTC");
            println!("Time start: {}", custom_format);
            // Compute effective batch size
            let effective_batch_size = if zip_pack_batch_size == 0 { file_splits } else { zip_pack_batch_size };
            
            println!(
                "Output Path:{}, Schema Path:{}, Total Records:{}, CSV files:{}, ThreadPool Size:{}, Zip Batch Size:{}",
                &output_path, schema_path, num_records.to_formatted_string(&Locale::fr),
                file_splits.to_formatted_string(&Locale::fr),
                thread_pool_size,
                effective_batch_size.to_formatted_string(&Locale::fr)
            );
            let start_time = Instant::now();

            let _ = fs::create_dir_all(&output_path);
            write_csv_concurrent(
                output_path,
                schema_path,
                num_records as i64,
                delimiter,
                file_splits,
                thread_pool_size,
                effective_batch_size,  // New parameter
            ).expect("Failed to write concurrent CSV files");

            println!("Time finish: {}", Utc::now().format("%Y-%m-%d %H:%M:%S.%3f UTC"));
            println!("Time spent: {:.3} minutes", (start_time.elapsed().as_secs_f64()/60.0));

        }
    }

    Ok(())
}

fn main() {
    ok_or_exit(run())
}
