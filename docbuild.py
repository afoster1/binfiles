#!/usr/bin/env python3

# To build a document use a command like `python docbuild.py --definition [definition.yaml]`
# Where the `definition.yaml` file is for example:
#    template: template.tex
#    cover-template: cover-page.tex
#    title: Title
#    subtitle: Subtitle
#    date: YYYY-MM-DD
#    version: 1.1a
#    chapters:
#      - chapter1.md
#      - chapter2.md
#    chapter-page-breaks: true
#    filters:
#      - docbuild.lua
#    sort-property: sort_index
#    assets-folder: path/to/assets
#    output: output.pdf

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote

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

def parse_boolean_value(value) -> bool | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)

    normalized = str(value).strip().lower()
    if normalized in {"true", "yes", "y", "1"}:
        return True
    if normalized in {"false", "no", "n", "0"}:
        return False
    return None


def convert_obsidian_embed_images(text: str, source_path: Path | None = None, temp_dir: Path | None = None, definition_dir: Path | None = None, assets_dir: Path | None = None, verbose: bool = False) -> str:
    pattern = re.compile(r"!\[\[([^\]|]+?)(?:\|([^\]]+))?\]\]")

    def resolve_target_path(image_path: str) -> str:
        candidate = Path(image_path)
        candidate_exists = False

        if not candidate.is_absolute():
            checked: list[Path] = []

            if assets_dir is not None:
                assets_name = assets_dir.name.lower()
                already_in_assets = bool(candidate.parts) and candidate.parts[0].lower() == assets_name
                if not already_in_assets:
                    checked.append((assets_dir / candidate).resolve(strict=False))

            if definition_dir is not None:
                checked.append((definition_dir / candidate).resolve(strict=False))

            if source_path is not None:
                checked.append((source_path.parent / candidate).resolve(strict=False))

            if temp_dir is not None:
                checked.append((temp_dir / candidate).resolve(strict=False))

            for checked_path in checked:
                if checked_path.exists():
                    candidate = checked_path.resolve(strict=False)
                    candidate_exists = True
                    break

        if not candidate_exists:
            if candidate.is_absolute():
                candidate = candidate.resolve(strict=False)
            else:
                for base in (
                    source_path.parent if source_path is not None else None,
                    definition_dir,
                    temp_dir,
                    Path.cwd(),
                ):
                    if base is not None:
                        candidate = (base / candidate).resolve(strict=False)
                        break
                else:
                    candidate = candidate.resolve(strict=False)

        return candidate.as_posix()

    def replace(match: re.Match[str]) -> str:
        image_path = match.group(1).strip()
        if not image_path:
            return match.group(0)

        resolved_path = Path(resolve_target_path(image_path)).resolve(strict=False)
        src_value = resolved_path.as_posix().replace('\\', '/')
        if any(ch.isspace() for ch in src_value) or any(ch in src_value for ch in "()[]"):
            src_value = f"<{src_value}>"
        size = match.group(2)
        if size and size.strip():
            size_value = size.strip()
            if not size_value.lower().endswith("px") and "x" not in size_value.lower():
                size_value = f"{size_value}px"
            return f'![]({src_value}){{width={size_value}}}'

        return f'![]({src_value})'

    return pattern.sub(replace, text)


def create_temp_markdown_copy(source_path: Path, base_dir: Path, assets_dir: Path | None = None, verbose: bool = False) -> Path:
    temp_handle = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8", dir=str(base_dir))
    temp_handle.close()
    temp_path = Path(temp_handle.name)

    original_text = source_path.read_text(encoding="utf-8")
    converted_text = convert_obsidian_embed_images(original_text, source_path=source_path, temp_dir=base_dir, definition_dir=base_dir, assets_dir=assets_dir, verbose=verbose)
    with temp_path.open("w", encoding="utf-8") as fh:
        fh.write(converted_text)
        if not converted_text.endswith("\n"):
            fh.write("\n")

    return temp_path


def deduplicate_paths(paths: list[Path]) -> list[Path]:
    seen: set[str] = set()
    unique: list[Path] = []
    for path in paths:
        resolved = path.resolve(strict=False)
        key = str(resolved).lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(path)
    return unique


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


def apply_cover_template(template_path: Path, cover_template_value: str | Path | None, base_dir: Path) -> Path:
    if cover_template_value is None or str(cover_template_value).strip() == "":
        return template_path

    cover_path = resolve_config_path(base_dir, cover_template_value)
    if not cover_path.exists():
        fallback_cover_path = resolve_config_path(ROOT, cover_template_value)
        if fallback_cover_path.exists():
            cover_path = fallback_cover_path
    if not cover_path.exists():
        raise SystemExit(f"ERROR: cover template file not found: {cover_path}")

    cover_text = cover_path.read_text(encoding="utf-8")
    template_text = template_path.read_text(encoding="utf-8")

    if "$body$" in cover_text or "\\begin{document}" in cover_text or "\\end{document}" in cover_text:
        raise SystemExit(
            f"ERROR: cover template '{cover_path}' is a full document template and cannot be used as a cover page. "
            "Use a fragment containing only the titlepage content, or set 'template' to the full document template instead."
        )

    title_start = template_text.find("\\begin{titlepage}")
    title_end_marker = "\\end{titlepage}"
    title_end = template_text.find(title_end_marker)
    if title_start != -1 and title_end != -1 and title_end >= title_start:
        title_end += len(title_end_marker)
        combined_text = template_text[:title_start] + cover_text + template_text[title_end:]
    else:
        document_start = template_text.find("\\begin{document}")
        if document_start == -1:
            return template_path
        document_start += len("\\begin{document}")
        combined_text = template_text[:document_start] + "\n" + cover_text + "\n" + template_text[document_start:]

    temp_handle = tempfile.NamedTemporaryFile("w", suffix=".tex", delete=False, encoding="utf-8", dir=str(base_dir))
    temp_handle.write(combined_text)
    temp_handle.close()
    return Path(temp_handle.name)


def doc_build_command(doc_path: Path, verbose: bool = False) -> tuple[list[str], Path, list[Path], Path | None]:
    definition = load_doc_definition(doc_path)
    base_dir = doc_path.parent

    template_value = definition.get("template") or "docbuild-template.tex"

    template_path = resolve_config_path(base_dir, template_value)
    if not template_path.exists():
        fallback_template_path = resolve_config_path(ROOT, template_value)
        if fallback_template_path.exists():
            template_path = fallback_template_path
    if not template_path.exists():
        raise SystemExit(f"ERROR: template file not found: {template_path}")

    cover_template_value = definition.get("cover-template")
    if cover_template_value is None:
        cover_template_value = definition.get("cover_template")
    if cover_template_value is None or str(cover_template_value).strip() == "":
        default_cover_path = resolve_config_path(ROOT, "docbuild-cover.tex")
        if default_cover_path.exists():
            cover_template_value = default_cover_path
    template_path = apply_cover_template(template_path, cover_template_value, base_dir)

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

    chapter_paths = deduplicate_paths(chapter_paths)

    chapter_page_breaks = parse_boolean_value(definition.get("chapter-page-breaks"))
    if chapter_page_breaks is None:
        chapter_page_breaks = parse_boolean_value(definition.get("chapter_page_breaks"))

    assets_folder_value = definition.get("assets-folder")
    if assets_folder_value is None:
        assets_folder_value = definition.get("assets_folder")

    assets_dir = None
    if assets_folder_value is not None and str(assets_folder_value).strip() != "":
        assets_dir = resolve_config_path(base_dir, str(assets_folder_value))
        if not assets_dir.exists():
            raise SystemExit(f"ERROR: assets folder not found: {assets_dir}")

    temp_input_path = None
    input_paths = []
    if chapter_page_breaks:
        tmp_handle = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8", dir=str(base_dir))
        tmp_handle.close()
        temp_input_path = Path(tmp_handle.name)
        with temp_input_path.open("w", encoding="utf-8") as fh:
            for index, chapter in enumerate(chapter_paths):
                if index > 0:
                    fh.write("\\clearpage\n\n")
                chapter_text = convert_obsidian_embed_images(chapter.read_text(encoding="utf-8"), source_path=chapter, temp_dir=base_dir, definition_dir=base_dir, assets_dir=assets_dir, verbose=verbose)
                fh.write(chapter_text)
                if not chapter_text.endswith("\n"):
                    fh.write("\n")
        input_paths = [temp_input_path]
    else:
        input_paths = [create_temp_markdown_copy(chapter, base_dir, assets_dir=assets_dir, verbose=verbose) for chapter in chapter_paths]

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
        for field in ("title", "subtitle", "date", "author", "subject", "keywords", "version"):
            value = chapter_metadata.get(field)
            if value is not None and field not in metadata:
                metadata[field] = str(value)

    for field in ("title", "subtitle", "date", "author", "subject", "keywords", "version"):
        if field in definition and definition[field] is not None:
            metadata[field] = str(definition[field])

    command = ["pandoc"]
    command.extend(str(path) for path in input_paths)
    command.extend(["--from=markdown+raw_tex", "--template", str(template_path)])
    for field, value in metadata.items():
        command.extend(["--metadata", f"{field}={value}"])
    for filter_path in filter_paths:
        command.extend(["--lua-filter", str(filter_path)])
    command.extend(["--pdf-engine=xelatex", "-o", str(output_file)])

    if sort_field and verbose:
        print("Chapter order:")
        for chapter in chapter_paths:
            print(f"  - {chapter.name} ({parse_frontmatter_sort_value(chapter, sort_field)})")

    return command, output_file, chapter_paths, temp_input_path

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
    command, output_pdf, _, temp_input_path = doc_build_command(definition_path, verbose=args.verbose)

    env = os.environ.copy()
    if args.verbose:
        env["DB_VERBOSE"] = "1"

    try:
        run_command(command, env=env)
    finally:
        if temp_input_path is not None:
            try:
                temp_input_path.unlink(missing_ok=True)
            except OSError:
                pass

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
