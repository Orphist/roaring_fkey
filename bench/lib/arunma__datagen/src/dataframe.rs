use polars::prelude::*;
use rayon::prelude::*;
use crate::schema::{Schema, Column};
use crate::fakegen;
use crate::{DType, DValue};

pub fn generate_dataframe(schema: Schema, num_rows: usize) -> Result<DataFrame, PolarsError> {
    let columns: Vec<Series> = schema.dataset.columns
        .par_iter()
        .map(|col| {
            generate_series(col, num_rows)
        })
        .collect();
    
    DataFrame::new(columns)
}

fn generate_series(col: &Column, num_rows: usize) -> Series {
    match col.dtype {
        DType::Boolean => {
            let data: Vec<bool> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::Boolean(v) = fakegen::generate_fake_data(col.clone()) { v } else { false }
                })
                .collect();
            Series::new(&col.name, data)
        },
        DType::Int | DType::Age => {
            let data: Vec<i32> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::Int(v) = fakegen::generate_fake_data(col.clone()) { v } else { 0 }
                })
                .collect();
            Series::new(&col.name, data)
        },
        DType::Long => {
            let data: Vec<i64> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::Long(v) = fakegen::generate_fake_data(col.clone()) { v } else { 0 }
                })
                .collect();
            Series::new(&col.name, data)
        },
        DType::Float => {
            let data: Vec<f32> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::Float(v) = fakegen::generate_fake_data(col.clone()) { v } else { 0.0 }
                })
                .collect();
            Series::new(&col.name, data)
        },
        DType::Double => {
            let data: Vec<f64> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::Double(v) = fakegen::generate_fake_data(col.clone()) { v } else { 0.0 }
                })
                .collect();
            Series::new(&col.name, data)
        },
        DType::String | DType::Name | DType::City | DType::Phone | DType::Latitude | DType::Longitude => {
            let data: Vec<String> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::Str(v) = fakegen::generate_fake_data(col.clone()) { v } else { String::new() }
                })
                .collect();
            Series::new(&col.name, data)
        },
        DType::Date => {
            let data: Vec<String> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::Date(v) = fakegen::generate_fake_data(col.clone()) { v } else { String::new() }
                })
                .collect();
            Series::new(&col.name, data)
        },
        DType::DateTime => {
            let data: Vec<String> = (0..num_rows)
                .into_par_iter()
                .map(|_| {
                    if let DValue::DateTime(v) = fakegen::generate_fake_data(col.clone()) { v } else { String::new() }
                })
                .collect();
            Series::new(&col.name, data)
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::schema::Schema;

    #[test]
    fn test_generate_dataframe() {
        let schema = Schema::from_path("./test_data/schema_simple.yaml".to_string()).unwrap();
        let df = generate_dataframe(schema, 100).unwrap();
        println!("{:?}", df);
        assert_eq!(df.height(), 100);
        assert_eq!(df.width(), 6); // id, name, age, adult, gender, date (from schema_simple.yaml based on previous logs)
    }
}
