#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/pure-build-env.sh"
cd "$PURE_PROJECT_ROOT"
[[ -x "$FLUTTER_ROOT/bin/flutter" ]] || { echo 'Run scripts/pure-build-setup.sh first.' >&2; exit 1; }
apply_patch_once() {
  local target="$1" patch="$2" marker="$3" digest
  digest="$(shasum -a 256 "$patch" | cut -d ' ' -f 1)"
  if [[ -f "$marker" ]]; then
    [[ "$(cat "$marker")" == "$digest" ]] || { echo "Patch changed: $patch; rebuild the dedicated toolchain." >&2; exit 1; }
    return
  fi
  local patch_stats
  patch_stats="$(GIT_CEILING_DIRECTORIES="$(dirname "$target")" git -C "$target" apply --numstat "$patch")"
  [[ -n "$patch_stats" ]] || { echo "Patch matched no files: $patch" >&2; exit 1; }
  GIT_CEILING_DIRECTORIES="$(dirname "$target")" git -C "$target" apply --check "$patch"
  GIT_CEILING_DIRECTORIES="$(dirname "$target")" git -C "$target" apply "$patch"
  mkdir -p "$(dirname "$marker")"
  printf '%s\n' "$digest" > "$marker"
}
flutter_patches=(modal_barrier text_selection mouse_cursor image_anim layout_builder navigation_drawer popup_menu fab null_safety_for_selectable_region selectable_region editable_text text_field scroll_position scrollable scrollable_gesture draggable_scrollable_sheet scaffold text text_painter sliver refresh_indicator bottom_sheet_android scroll_view navigator)
for patch in "${flutter_patches[@]}"; do
  apply_patch_once "$FLUTTER_ROOT" "$PURE_PROJECT_ROOT/lib/scripts/$patch.patch" "$FLUTTER_ROOT/.pure-patches/$patch"
done
flutter pub get --enforce-lockfile "$@"
material_dir="$(find "$PUB_CACHE/hosted/pub.dev" -maxdepth 1 -type d -name 'material_ui-*' | sort | tail -1)"
[[ -n "$material_dir" ]] || { echo 'material_ui dependency missing' >&2; exit 1; }
material_patches=(modal_barrier_material navigation_drawer popup_menu fab text_field scaffold refresh_indicator tabs bottom_sheet_android)
for patch in "${material_patches[@]}"; do
  apply_patch_once "$material_dir" "$PURE_PROJECT_ROOT/lib/scripts/material/$patch.patch" "$material_dir/.pure-patches/$patch"
done
