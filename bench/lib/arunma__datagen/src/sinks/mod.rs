use crate::errors::DataGenResult;
use crate::DValue;

pub mod csv_sink;

pub trait Sink {
    fn write(&mut self, value: DValue) -> DataGenResult<()>;
}
