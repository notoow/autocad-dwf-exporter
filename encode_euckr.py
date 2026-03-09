import argparse
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert a UTF-8 source file to CP949/EUC-KR for AutoCAD."
    )
    parser.add_argument("filename", help="Source file to convert.")
    parser.add_argument(
        "-o",
        "--output",
        help="Output path. Defaults to overwriting the source file.",
    )
    parser.add_argument(
        "--source-encoding",
        default="utf-8",
        help="Encoding used to read the source file. Default: utf-8",
    )
    parser.add_argument(
        "--target-encoding",
        default="cp949",
        help="Encoding used to write the output file. Default: cp949",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    source = Path(args.filename)
    output = Path(args.output) if args.output else source

    text = source.read_text(encoding=args.source_encoding)

    if output.resolve() == source.resolve():
        backup = source.with_name(source.name + ".utf8.bak")
        backup.write_bytes(source.read_bytes())
        print(f"Backup written to {backup}")

    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    output.write_bytes(normalized.replace("\n", "\r\n").encode(args.target_encoding))
    print(
        f"Converted {source} -> {output} "
        f"({args.source_encoding} -> {args.target_encoding})"
    )


if __name__ == "__main__":
    main()
