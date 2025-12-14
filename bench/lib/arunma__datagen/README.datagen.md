# DataGen - CSV Generator

DataGen is a robust tool written in Rust designed to generate large volumes of dummy data. This guide focuses specifically on its CSV generation capabilities.

## Installation

Ensure you have [Rust and Cargo](https://www.rust-lang.org/tools/install) installed.

```sh
# Clone the repository
git clone https://github.com/arunma/datagen.git
cd datagen

# Build the release binary
cargo build --release
```

## Usage

The general syntax for generating CSV data is:

```sh
./target/release/datagen csv <output_file> <schema_file> <num_records> [delimiter] [splits] [threads] [batch_size]
```

### Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `<output_file>` | Path where the generated CSV will be saved. | Required |
| `<schema_file>` | Path to the YAML schema definition file. | Required |
| `<num_records>` | Total number of records to generate. | Required |
| `[delimiter]` | Character to separate fields (e.g., `,`, `\|`). | `,` |
| `[splits]` | Number of files to split the output into. | `1` |
| `[threads]` | Number of threads to use for generation. | `32` |
| `[batch_size]` | Number of records per batch. | `0` (auto) |

## Schema Configuration

Schemas are defined in YAML format. Here is an example of a schema definition suitable for CSV generation:

```yaml
---
name: person_schema
dataset:
  name: person_table
  columns:
    - {name: id, dtype: int, not_null: false}
    - {name: name, dtype: name}
    - {name: age, dtype: int, min: 18, max: 90}
    - {name: adult, dtype: boolean, default: 'true'}
    - {name: gender, dtype: string, one_of: ["M", "F", "Other"]}
    - {name: dob, dtype: date, min: "01/01/1950", max: "31/12/2000", format: "%d/%m/%Y"}
    - {name: salary, dtype: float, min: 30000.00, max: 150000.00}
```

### Supported Data Types
- `int`, `long`, `float`, `double`
- `string`, `boolean`
- `date`, `datetime` (with format support)
- `name` (generates random names)

## Examples

### Basic Generation
Generate 100 records into a single file using a comma delimiter:
```sh
./target/release/datagen csv output.csv schema.yaml 100
```

### Advanced Generation
Generate 10 million records, split into 50 files, using a pipe `|` delimiter, running on 32 threads:
```sh
./target/release/datagen csv output_data/customers.csv schemas/schema_customers.yaml 10000000 "|" 50 32
```
