#!/bin/sh
if [ -z "${BASH_VERSION:-}" ]; then
exec /bin/bash "$0" "$@"
fi

case ":${SHELLOPTS:-}:" in
*:posix:*)
exec /bin/bash "$0" "$@"
;;
esac

set -euo pipefail

# sh doccCoverage.sh all    Get documentation coverage for all files
# sh doccCoverage.sh        Get documentation coverage for public files
# bash doccCoverage.sh all  Get documentation coverage for all files
# bash doccCoverage.sh      Get documentation coverage for public files
project='FTSDK.xcodeproj'
project_path="${project}/project.pbxproj"
scheme='FTSDK'
configuration="${CONFIGURATION:-Release}"
sdk="${SDK:-iphoneos}"
derived_data_path="${DERIVED_DATA_PATH:-build/DocCCoverageDerivedData}"
project_backup=''
docc_temp_root=''

cleanup(){
if [[ -n "$project_backup" && -f "$project_backup" ]]; then
cp "$project_backup" "$project_path"
rm -f "$project_backup"
fi
if [[ -n "$docc_temp_root" && -d "$docc_temp_root" ]]; then
rm -rf "$docc_temp_root"
fi
}
trap cleanup EXIT

changeFileAttributeToPublic(){
project_backup=$(mktemp "${TMPDIR:-/tmp}/FTSDKProject.XXXXXX.pbxproj")
cp "$project_path" "$project_backup"
perl -0pi -e 's/^(\s*[A-F0-9]+ \/\* [^\n]*\.h in Headers \*\/ = \{isa = PBXBuildFile; fileRef = [^;]+;)(?: settings = \{ATTRIBUTES = \([^)]*\); \};)? \};$/$1 settings = {ATTRIBUTES = (Public, ); }; };/mg' "$project_path"
}

createTempDocCCatalog(){
if [[ -z "$docc_temp_root" ]]; then
echo "error: docc temp root not initialized" >&2
exit 1
fi
local docc_catalog="${docc_temp_root}/${scheme}.docc"
mkdir -p "$docc_catalog"
printf '# %s\n\nAPI documentation coverage.\n' "$scheme" > "${docc_catalog}/${scheme}.md"
echo "$docc_catalog"
}

createTempDocCRoot(){
docc_temp_root=$(mktemp -d "${TMPDIR:-/tmp}/FTSDKDocs.XXXXXX")
}

findSymbolGraphDir(){
local search_root="${derived_data_path}/Build/Intermediates.noindex"
local found=''
while IFS= read -r candidate; do
found="$candidate"
break
done < <(find "$search_root" -type d -path "*/${scheme}.build/symbol-graph" 2>/dev/null)

if [[ -z "$found" ]]; then
echo "error: symbol graph directory not found under ${search_root}" >&2
exit 1
fi

echo "$found"
}

filterSymbolGraphsForCoverage(){
local symbol_graph_dir="$1"
ruby -rjson - "$symbol_graph_dir" <<'RUBY'
root = ARGV.fetch(0)
synthesized_marker = "::SYNTHESIZED::"
clang_identifiers = {}

Dir.glob(File.join(root, "**", "*.symbols.json")).each do |path|
  next unless path.split(File::SEPARATOR).include?("clang")

  data = JSON.parse(File.read(path))
  Array(data["symbols"]).each do |symbol|
    precise_identifier = symbol.dig("identifier", "precise").to_s
    clang_identifiers[precise_identifier] = true unless precise_identifier.empty?
  end
end

Dir.glob(File.join(root, "**", "*.symbols.json")).each do |path|
  data = JSON.parse(File.read(path))
  symbols = Array(data["symbols"])
  relationships = Array(data["relationships"])
  is_swift_graph = path.split(File::SEPARATOR).include?("swift")

  removed_identifiers = {}
  filtered_symbols = symbols.reject do |symbol|
    precise_identifier = symbol.dig("identifier", "precise").to_s
    should_remove =
      precise_identifier.include?(synthesized_marker) ||
      (is_swift_graph && precise_identifier.start_with?("c:") &&
        clang_identifiers[precise_identifier])

    removed_identifiers[precise_identifier] = true if should_remove
    should_remove
  end

  filtered_relationships = relationships.reject do |relationship|
    removed_identifiers[relationship["source"]] ||
      removed_identifiers[relationship["target"]] ||
      relationship["source"].to_s.include?(synthesized_marker) ||
      relationship["target"].to_s.include?(synthesized_marker)
  end

  next if filtered_symbols.length == symbols.length &&
    filtered_relationships.length == relationships.length

  data["symbols"] = filtered_symbols
  data["relationships"] = filtered_relationships if data.key?("relationships")
  File.write(path, JSON.pretty_generate(data))
end
RUBY
}

moduleNameFromSymbolGraphs(){
local symbol_graph_dir="$1"
ruby -rjson - "$symbol_graph_dir" <<'RUBY'
root = ARGV.fetch(0)
Dir.glob(File.join(root, "**", "*.symbols.json")).each do |path|
  module_name = JSON.parse(File.read(path)).dig("module", "name").to_s
  next if module_name.empty?

  puts module_name
  exit
end
RUBY
}

missingClangRootSymbolNamesFromSwiftGraph(){
local symbol_graph_dir="$1"
ruby -rjson - "$symbol_graph_dir" <<'RUBY'
root = ARGV.fetch(0)
clang_identifiers = {}
swift_roots = {}

Dir.glob(File.join(root, "**", "*.symbols.json")).each do |path|
  data = JSON.parse(File.read(path))
  is_clang_graph = path.split(File::SEPARATOR).include?("clang")
  is_swift_graph = path.split(File::SEPARATOR).include?("swift")

  Array(data["symbols"]).each do |symbol|
    precise_identifier = symbol.dig("identifier", "precise").to_s
    clang_identifiers[precise_identifier] = true if is_clang_graph

    next unless is_swift_graph && precise_identifier.start_with?("c:")
    path_components = Array(symbol["pathComponents"])
    next unless path_components.length == 1

    swift_roots[precise_identifier] = path_components.first
  end
end

swift_roots.each do |precise_identifier, symbol_name|
  puts symbol_name unless clang_identifiers[precise_identifier]
end
RUBY
}

clangTargetForSDK(){
case "$sdk" in
iphoneos)
echo "arm64-apple-ios12.0"
;;
iphonesimulator)
echo "arm64-apple-ios12.0-simulator"
;;
appletvos)
echo "arm64-apple-tvos12.0"
;;
appletvsimulator)
echo "arm64-apple-tvos12.0-simulator"
;;
*)
echo "arm64-apple-ios12.0"
;;
esac
}

patchSymbolGraphModuleName(){
local symbol_graph_path="$1"
local module_name="$2"
ruby -rjson - "$symbol_graph_path" "$module_name" <<'RUBY'
path = ARGV.fetch(0)
module_name = ARGV.fetch(1)
data = JSON.parse(File.read(path))
data["module"] ||= {}
data["module"]["name"] = module_name
File.write(path, JSON.pretty_generate(data))
RUBY
}

pruneExistingClangSymbols(){
local symbol_graph_dir="$1"
local supplemental_graph="$2"
ruby -rjson - "$symbol_graph_dir" "$supplemental_graph" <<'RUBY'
root = ARGV.fetch(0)
supplemental_path = ARGV.fetch(1)
existing_identifiers = {}

Dir.glob(File.join(root, "**", "*.symbols.json")).each do |path|
  next if path == supplemental_path
  next unless path.split(File::SEPARATOR).include?("clang")

  data = JSON.parse(File.read(path))
  Array(data["symbols"]).each do |symbol|
    precise_identifier = symbol.dig("identifier", "precise").to_s
    existing_identifiers[precise_identifier] = true unless precise_identifier.empty?
  end
end

data = JSON.parse(File.read(supplemental_path))
removed_identifiers = {}
data["symbols"] = Array(data["symbols"]).reject do |symbol|
  precise_identifier = symbol.dig("identifier", "precise").to_s
  should_remove = existing_identifiers[precise_identifier]
  removed_identifiers[precise_identifier] = true if should_remove
  should_remove
end

if data.key?("relationships")
  data["relationships"] = Array(data["relationships"]).reject do |relationship|
    removed_identifiers[relationship["source"]] ||
      removed_identifiers[relationship["target"]]
  end
end

if data["symbols"].empty?
  File.delete(supplemental_path)
else
  File.write(supplemental_path, JSON.pretty_generate(data))
end
RUBY
}

sourceHeaderForSymbolName(){
local symbol_name="$1"
local header_path=''
while IFS= read -r candidate; do
header_path="$candidate"
break
done < <(find Sources -type f -name "${symbol_name}.h" 2>/dev/null)

if [[ -n "$header_path" ]]; then
echo "${PWD}/${header_path}"
fi
}

sourceHeaderSearchArgs(){
while IFS= read -r dir; do
printf '%s\0%s\0' "-I" "${PWD}/${dir}"
done < <(find Sources -type d 2>/dev/null)
}

supplementMissingClangSymbols(){
local filtered_symbol_graph_dir="$1"
local module_name
module_name=$(moduleNameFromSymbolGraphs "$filtered_symbol_graph_dir")
if [[ -z "$module_name" ]]; then
echo "warning: module name not found; skipping supplemental DocC symbol graph" >&2
return
fi

local sdk_path
sdk_path=$(xcrun --sdk "$sdk" --show-sdk-path)
local module_cache_dir="${docc_temp_root}/clang-module-cache"
local supplemental_dir="${filtered_symbol_graph_dir}/clang/supplemental"
mkdir -p "$module_cache_dir" "$supplemental_dir"

local include_args=()
while IFS= read -r -d '' arg; do
include_args+=("$arg")
done < <(sourceHeaderSearchArgs)

local symbol_name
while IFS= read -r symbol_name; do
local source_header
source_header=$(sourceHeaderForSymbolName "$symbol_name")
if [[ -z "$source_header" ]]; then
echo "warning: ${symbol_name}.h not found; skipping supplemental DocC symbol graph" >&2
continue
fi

local supplemental_graph="${supplemental_dir}/${symbol_name}.symbols.json"
if ! xcrun --sdk "$sdk" clang -extract-api --pretty-sgf \
  -x objective-c-header \
  -target "$(clangTargetForSDK)" \
  -isysroot "$sdk_path" \
  -fobjc-arc \
  -fmodules \
  -fmodules-cache-path="$module_cache_dir" \
  -fmodule-name="$module_name" \
  "${include_args[@]}" \
  -o "$supplemental_graph" \
  "$source_header"; then
echo "warning: failed to extract supplemental DocC symbols for ${symbol_name}.h" >&2
rm -f "$supplemental_graph"
continue
fi

patchSymbolGraphModuleName "$supplemental_graph" "$module_name"
pruneExistingClangSymbols "$filtered_symbol_graph_dir" "$supplemental_graph"
done < <(missingClangRootSymbolNamesFromSwiftGraph "$filtered_symbol_graph_dir" | sort -u)
}

createFilteredSymbolGraphDir(){
local symbol_graph_dir="$1"
if [[ -z "$docc_temp_root" ]]; then
echo "error: docc temp root not initialized" >&2
exit 1
fi
local filtered_symbol_graph_dir="${docc_temp_root}/symbol-graph"
cp -R "$symbol_graph_dir" "$filtered_symbol_graph_dir"

# Swift symbol graphs contain importer-generated Objective-C views of public
# headers and synthesized members such as SwiftUI protocol extension methods.
# Remove only importer views that duplicate a Clang symbol; a non-duplicated
# Swift symbol remains visible to coverage rather than being silently ignored.
supplementMissingClangSymbols "$filtered_symbol_graph_dir"
filterSymbolGraphsForCoverage "$filtered_symbol_graph_dir"
echo "$filtered_symbol_graph_dir"
}

doccCoverage(){
echo '----- Cleaning in progress -----'
xcodebuild -project "$project" \
           -scheme "$scheme" \
           -configuration "$configuration" \
           -sdk "$sdk" \
           -derivedDataPath "$derived_data_path" \
           clean -quiet
echo 'Cleaning completed -->>> build'
xcodebuild -project "$project" \
           -scheme "$scheme" \
           -configuration "$configuration" \
           -sdk "$sdk" \
           -derivedDataPath "$derived_data_path" \
           DOCC_EXTRACT_SWIFT_INFO_FOR_OBJC_SYMBOLS=NO \
           -quiet
echo 'build completion -->>> docc'
local docc_catalog
local symbol_graph_dir
local filtered_symbol_graph_dir
createTempDocCRoot
docc_catalog=$(createTempDocCCatalog)
symbol_graph_dir=$(findSymbolGraphDir)
filtered_symbol_graph_dir=$(createFilteredSymbolGraphDir "$symbol_graph_dir")
xcrun docc convert "$docc_catalog" \
--fallback-display-name "$scheme" \
--fallback-bundle-identifier com.ft.sdk.FTSDK \
--fallback-bundle-version 1.0 \
--additional-symbol-graph-dir "$filtered_symbol_graph_dir" \
--experimental-documentation-coverage \
--coverage-summary-level detailed
}

# If "all", get documentation coverage for all files
FT_ALL_FILE_COVERAGE="${1:-}"
echo "----- Start -----"

if [[ "$FT_ALL_FILE_COVERAGE" == "all" ]]; then
echo "-----changeFileAttributeToPublic Start-----"
changeFileAttributeToPublic
echo "-----changeFileAttributeToPublic End-----"
fi

echo "-----Coverage Start-----"
doccCoverage
echo "-----Coverage End-----"
echo "----- End -----"
