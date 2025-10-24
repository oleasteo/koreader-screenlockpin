#!/usr/bin/env bash

root_dir="$(realpath "$(dirname "$0")")"
target_dir="$root_dir/target"
name="screenlockpin.koplugin"
version="2025.10-2"
id="$name--$version"

[ -d "$target_dir/bundle" ] && rm -rf "$target_dir/bundle"
rm -f "$target_dir/release/$id"* 2>/dev/null || true

mkdir -p "$target_dir/release" "$target_dir/bundle"
cp -r "$root_dir/$name" "$target_dir/bundle/"

cp "$root_dir/LICENSE" "$root_dir/README.md" "$root_dir/CHANGELOG.md" "$target_dir/bundle/$name/"

(
  cd "$target_dir/bundle"
  tar -czf ../release/"$id.tar.gz" *
  zip -qr ../release/"$id.zip" *
)
