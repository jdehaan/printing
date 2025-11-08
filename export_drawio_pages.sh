#!/bin/bash

# This script exports each page of a .drawio file as a separate SVG file.
# Usage: ./export_drawio_pages.sh <input.drawio>

# Check if the input file is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <input.drawio>"
  exit 1
fi

INPUT_FILE="$1"
BASENAME=$(basename "$INPUT_FILE" .drawio)

# Check if the drawio command is available
if ! command -v drawio &> /dev/null; then
  echo "Error: drawio command not found. Please ensure it is installed and in your PATH."
  exit 1
fi

# Debugging: Print the drawio version
echo "Using drawio version: $(drawio --version)"

# Check if the input file exists and is readable
if [ ! -r "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' not found or not readable!"
  exit 1
fi

# Determine the number of pages by parsing the XML content
# .drawio files contain <diagram> elements, one per page
PAGE_COUNT=$(grep -o '<diagram' "$INPUT_FILE" | wc -l)
if [ "$PAGE_COUNT" -eq 0 ]; then
  echo "Error: No pages found in '$INPUT_FILE'. Ensure the file is a valid .drawio file."
  exit 1
fi

# Debugging: Print the number of pages detected
echo "Detected $PAGE_COUNT pages in '$INPUT_FILE'"

# Create output directory
OUTPUT_DIR="svg"
mkdir -p "$OUTPUT_DIR"

# Export each page as an SVG
for ((i=1; i<=PAGE_COUNT; i++)); do
  # Extract the page name from the XML content
  PAGE_NAME=$(grep -oP '<diagram(?: [^>]*?)? name="\K[^"]+' "$INPUT_FILE" | sed -n "${i}p")
  if [ -z "$PAGE_NAME" ]; then
    PAGE_NAME="page_${i}"
  fi

  OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}_${PAGE_NAME}.svg"
  echo "Exporting page $i ('$PAGE_NAME') to $OUTPUT_FILE..."

  # Note: drawio uses 1-based page indexing, suppress stderr to reduce noise
  drawio --export --page-index $i --format svg --output "$OUTPUT_FILE" "$INPUT_FILE" 2>/dev/null

  # Check if the file was created and has content
  if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    echo "✓ Exported page $i ('$PAGE_NAME') to $OUTPUT_FILE"
  else
    echo "✗ Error exporting page $i ('$PAGE_NAME') (file not created or empty)"
    # Remove empty file if it exists
    [ -f "$OUTPUT_FILE" ] && rm "$OUTPUT_FILE"
  fi
done

# Debugging: Print the output directory
echo "Exporting pages to directory: $OUTPUT_DIR"

echo "All pages exported to '$OUTPUT_DIR'"