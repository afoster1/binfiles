#!/usr/bin/env python3

# To build a document use a command like `python docbuild.py --definition [definition.yaml]`
# Where the `definition.yaml` file is for example:
#    template: template.tex
#    title: Title
#    subtitle: Subtitle
#    date: YYYY-MM-DD
#    chapters:
#      - chapter1.md
#      - chapter2.md
#    filters:
#      - docbuild.lua
#    sort-property: sort_index
#    output: output.pdf

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

ROOT = Path(__file__).resolve().parent

def ensure_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(f"ERROR: {name} was not found in PATH. Install it and try again.")

def run_command(command: list[str], env: dict[str, str] | None = None) -> None:
    print("$", " ".join(command))
    result = subprocess.run(command, cwd=str(ROOT), env=env, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)

def resolve_config_path(base_dir: Path, value: str | Path) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = (base_dir / path).resolve()
    return path

def ensure_output_file_writable(path: Path) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("wb") as fh:
            fh.flush()
    except OSError as exc:
        raise SystemExit(f"ERROR: cannot create or write output file '{path}': {exc}") from exc

def load_doc_definition(doc_path: Path) -> dict:
    if yaml is None:
        raise SystemExit("ERROR: PyYAML is required to read definition files.")

    doc_path = doc_path.resolve()
    if not doc_path.exists():
        raise SystemExit(f"ERROR: document definition file not found: {doc_path}")

    with doc_path.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}

    if not isinstance(data, dict):
        raise SystemExit(f"ERROR: document definition file must contain a YAML mapping: {doc_path}")

    return data

def parse_frontmatter_sort_value(path: Path, sort_field: str) -> float:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise SystemExit(f"ERROR: frontmatter field '{sort_field}' not found in {path}")

    try:
        _, frontmatter, _ = text.split("---", 2)
    except ValueError:
        raise SystemExit(f"ERROR: frontmatter field '{sort_field}' not found in {path}")

    try:
        data = yaml.safe_load(frontmatter) or {}
    except Exception as exc:  # pragma: no cover
        raise SystemExit(f"ERROR: could not parse frontmatter in {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise SystemExit(f"ERROR: frontmatter in {path} is not a YAML mapping")

    if sort_field not in data:
        raise SystemExit(f"ERROR: frontmatter field '{sort_field}' not found in {path}")

    value = data[sort_field]
    try:
        return float(value)
    except (TypeError, ValueError):
        raise SystemExit(f"ERROR: frontmatter field '{sort_field}' in {path} is not numeric: {value!r}")

def load_frontmatter_metadata(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}

    if not text.startswith("---"):
        return {}

    try:
        _, frontmatter, _ = text.split("---", 2)
    except ValueError:
        return {}

    try:
        data = yaml.safe_load(frontmatter) or {}
    except Exception:  # pragma: no cover
        return {}

    return data if isinstance(data, dict) else {}

def doc_build_command(doc_path: Path, verbose: bool = False) -> tuple[list[str], Path, list[Path]]:
    definition = load_doc_definition(doc_path)
    base_dir = doc_path.parent

    template_value = definition.get("template")
    if not template_value:
        raise SystemExit(f"ERROR: definition file is missing a 'template' entry: {doc_path}")

    template_path = resolve_config_path(base_dir, template_value)
    if not template_path.exists():
        fallback_template_path = resolve_config_path(ROOT, template_value)
        if fallback_template_path.exists():
            template_path = fallback_template_path
    if not template_path.exists():
        raise SystemExit(f"ERROR: template file not found: {template_path}")

    chapters_value = definition.get("chapters")
    if chapters_value is None or not isinstance(chapters_value, list) or not chapters_value:
        chapter_paths = sorted(
            (path for path in base_dir.iterdir() if path.is_file() and path.suffix.lower() in {".md", ".markdown"}),
            key=lambda path: path.name.lower(),
        )
        if not chapter_paths:
            raise SystemExit(f"ERROR: definition file must contain a non-empty 'chapters' list or at least one Markdown chapter file in {base_dir}: {doc_path}")
    else:
        chapter_paths = [resolve_config_path(base_dir, item) for item in chapters_value]
        for chapter in chapter_paths:
            if not chapter.exists():
                raise SystemExit(f"ERROR: chapter file not found: {chapter}")

    sort_field = definition.get("sort")
    if not sort_field:
        for key in ("sort-property", "sort_property", "sort"):
            if key in definition:
                sort_field = definition.get(key)
                break

    if sort_field:
        chapter_paths = sorted(
            chapter_paths,
            key=lambda chapter: parse_frontmatter_sort_value(chapter, sort_field),
        )

    filters_value = definition.get("filters", [])
    if filters_value is None:
        filters_value = []
    if isinstance(filters_value, str):
        filters_value = [filters_value]
    if not isinstance(filters_value, list):
        raise SystemExit(f"ERROR: 'filters' must be a list in {doc_path}")

    filter_paths: list[Path] = []
    for item in filters_value:
        filter_path = resolve_config_path(base_dir, item)
        if not filter_path.exists():
            candidate_path = resolve_config_path(ROOT, item)
            if candidate_path.exists():
                filter_path = candidate_path
        if not filter_path.exists():
            raise SystemExit(f"ERROR: filter file not found: {filter_path}")
        filter_paths.append(filter_path)

    output_path = definition.get("output")
    if output_path:
        output_file = resolve_config_path(base_dir, output_path)
    else:
        output_file = doc_path.with_suffix(".pdf")

    ensure_output_file_writable(output_file)

    metadata: dict[str, str] = {}
    for chapter in chapter_paths:
        chapter_metadata = load_frontmatter_metadata(chapter)
        for field in ("title", "subtitle", "date", "author", "subject", "keywords"):
            value = chapter_metadata.get(field)
            if value is not None and field not in metadata:
                metadata[field] = str(value)

    for field in ("title", "subtitle", "date", "author", "subject", "keywords"):
        if field in definition and definition[field] is not None:
            metadata[field] = str(definition[field])

    command = ["pandoc"]
    command.extend(str(path) for path in chapter_paths)
    command.extend(["--from=markdown", "--template", str(template_path)])
    for field, value in metadata.items():
        command.extend(["--metadata", f"{field}={value}"])
    for filter_path in filter_paths:
        command.extend(["--lua-filter", str(filter_path)])
    command.extend(["--pdf-engine=xelatex", "-o", str(output_file)])

    if sort_field and verbose:
        print("Chapter order:")
        for chapter in chapter_paths:
            print(f"  - {chapter.name} ({parse_frontmatter_sort_value(chapter, sort_field)})")

    return command, output_file, chapter_paths

def main() -> None:
    parser = argparse.ArgumentParser(description="Build a PDF from Markdown chapters using a YAML document definition.")
    parser.add_argument("--definition", help="Path to YAML document definition file.")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose build output.")
    args = parser.parse_args()

    ensure_tool("pandoc")
    ensure_tool("xelatex")

    if not args.definition:
        raise SystemExit("ERROR: --definition is required. Pass the path to the YAML document definition file.")

    definition_path = Path(args.definition).expanduser().resolve()
    command, output_pdf, _ = doc_build_command(definition_path, verbose=args.verbose)

    env = os.environ.copy()
    if args.verbose:
        env["DB_VERBOSE"] = "1"

    run_command(command, env=env)
    print(f"PDF generated: {output_pdf}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Build interrupted.")
        sys.exit(130)
    except SystemExit:
        raise
    except Exception as exc:  # pragma: no cover
        print(f"Unexpected error: {exc}", file=sys.stderr)
        sys.exit(1)
