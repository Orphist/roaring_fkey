use structopt::StructOpt;
use std::num::ParseIntError;

#[derive(Debug, StructOpt)]
#[structopt(
name = "docgen",
about = "An easy to use tool to generate fake data in bulk and export it as Avro, Parquet or directly into your database as tables"
)]
pub struct Args {
    #[structopt(subcommand)]
    pub command: Command,
}

fn convert_to_u8(src: &str) -> Result<u8, ParseIntError> {
    Ok(src.as_bytes()[0])
}

#[derive(Debug, StructOpt)]
pub enum Command {
    #[structopt(name = "csv", alias = "c")]
    GenerateCSV {
        #[structopt(name = "output", alias = "o")]
        output_path: String,

        #[structopt(name = "schema", alias = "s")]
        schema_path: String,

        #[structopt(name = "numrecs", alias = "n")]
        num_records: usize,

        #[structopt(name = "delim", alias = "d", default_value = ",", parse(try_from_str = "convert_to_u8"))]
        delimiter: u8,

        #[structopt(name = "splits", alias = "sp", default_value = "1")]
        file_splits: usize,

        #[structopt(name = "threads", alias = "t", default_value = "32")]
        thread_pool_size: usize,

        #[structopt(name = "batch", alias = "b", default_value = "0")]
        zip_pack_batch_size: usize,
    },

}
