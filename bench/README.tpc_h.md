## TPC-H Data Generation

To generate TPC-H benchmark data for testing, use the `tpch_datagen.rb` script:

```sh
bench/bin/tpch_datagen.rb [options]
```

### Options

- `-s`, `--scale SCALE` - Scale factor (default: 1)
- `-C`, `--parallel COUNT` - Number of parallel segments (default: 1)
- `-S`, `--segment ID` - Segment ID (1-based, default: 1)
- `-o`, `--output DIR` - Output directory (default: ./generated)
- `-v`, `--verbose` - Verbose output
- `-h`, `--help` - Prints help message

### Examples

Generate data with scale factor 1:
```sh
bench/bin/tpch_datagen.rb -s 1
```

Generate data in parallel with 4 segments:
```sh
bench/bin/tpch_datagen.rb -s 1 -C 4 -S 1 -o ./generated
```

Generate with verbose output:
```sh
bench/bin/tpch_datagen.rb -s 1 -v
```

The script will generate TPC-H table data files in the specified output directory, which can then be used for benchmarking purposes.