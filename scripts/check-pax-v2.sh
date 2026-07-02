#!/usr/bin/env bash

set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

dangerous_re='^(write gpt|create partition|commit partition table|format |mount |umount |install package |install bundle |install desktop |write file |exec command |user create |user add-group |user set-password |set password for |service enable |service disable |service start |service stop |initramfs build |bootloader install |bootloader entry |seed apply |recover )'
known_types_re='^(Path|String|Symbol|Package|Bundle|Desktop|Service|Command|Url|Bool|Int|List<(Path|String|Symbol|Package|Bundle|Desktop|Service|Command|Url|Bool|Int)>)$'

strip_strings() {
  local text="$1"
  awk -v line="$text" '
    BEGIN {
      in_string = 0
      escaped = 0
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (in_string) {
          if (escaped) {
            escaped = 0
          } else if (c == "\\") {
            escaped = 1
          } else if (c == "\"") {
            in_string = 0
          }
          printf " "
          continue
        }
        if (c == "\"") {
          in_string = 1
          printf " "
          continue
        }
        printf "%s", c
      }
      printf "\n"
    }
  '
}

line_number_for() {
  local file="$1"
  local needle="$2"
  grep -n -F "$needle" "$file" | sed -n '1s/:.*//p'
}

check_v2_file() {
  local pax_file="$1"
  local header_line pending_danger pending_line line raw_line clean_no_strings token decl_type decl_name
  local -a declared_ids package_ids

  header_line="$(awk 'NF { print; exit }' "$pax_file")"
  if [[ ! "$header_line" =~ ^\[\.Praxis\ Config\ -\ .*[Vv]2.*\ \.praxis\.pax\./\]$ ]]; then
    printf 'PAX v2 file must have a v2 header label: %s\n' "$pax_file" >&2
    return 1
  fi

  declared_ids=()
  package_ids=()

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%%#*}"
    line="$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$line" ]] || continue

    if [[ "$line" =~ ^declare[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\{$ ]]; then
      decl_type="${BASH_REMATCH[1]}"
      decl_name="${BASH_REMATCH[2]}"
      case "$decl_type" in
        Disk|Partition)
          declared_ids+=("$(printf '%s' "$decl_type" | tr '[:upper:]' '[:lower:]').$decl_name")
          ;;
        *)
          printf 'unknown PAX v2 declaration type in %s: %s\n' "$pax_file" "$decl_type" >&2
          return 1
          ;;
      esac
    fi

    while IFS= read -r token; do
      [[ -n "$token" ]] || continue
      package_ids+=("$token")
    done < <(printf '%s\n' "$line" | grep -Eo 'pkg[[:space:]]+[A-Za-z0-9_][A-Za-z0-9_.+-]*(\.[A-Za-z0-9_][A-Za-z0-9_.+-]*)+' | awk '{print $2}')
  done < "$pax_file"

  pending_danger=''
  pending_line=''

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%%#*}"
    line="$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -n "$line" ]] || continue
    [[ "$line" == "$header_line" ]] && continue
    [[ "$line" == "}" ]] && continue
    [[ "$line" == *"{" ]] && [[ ! "$line" =~ ^(bootloader\ entry|declare|for|if)[[:space:]] ]] && {
      printf 'unsupported PAX v2 block in %s: %s\n' "$pax_file" "$line" >&2
      return 1
    }

    if [[ "$line" =~ ^(const|let)[[:space:]]+(.+?)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      binding_type="${BASH_REMATCH[2]}"
      binding_expr="${BASH_REMATCH[4]}"
      if [[ ! "$binding_type" =~ $known_types_re ]]; then
        printf 'unknown PAX v2 binding type in %s: %s\n' "$pax_file" "$binding_type" >&2
        return 1
      fi
      if [[ "$binding_type" == "Path" && ! "$binding_expr" =~ ^\"/ ]]; then
        printf 'PAX v2 Path binding must be an absolute string in %s: %s\n' "$pax_file" "$line" >&2
        return 1
      fi
    fi

    clean_no_strings="$(strip_strings "$line")"
    while IFS= read -r token; do
      [[ -n "$token" ]] || continue
      case "$token" in
        state.*)
          continue
          ;;
      esac
      if printf '%s\n' "${declared_ids[@]}" | grep -qx -- "$token"; then
        continue
      fi
      if printf '%s\n' "${package_ids[@]}" | grep -qx -- "$token"; then
        continue
      fi
      printf 'unresolved dotted PAX v2 path in %s: %s\n' "$pax_file" "$token" >&2
      return 1
    done < <(printf '%s\n' "$clean_no_strings" | grep -Eo '[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+' || true)

    if [[ "$line" =~ ^assert[[:space:]] ]]; then
      pending_danger=''
      pending_line=''
      continue
    fi

    if [[ "$line" =~ $dangerous_re ]]; then
      if [[ -n "$pending_danger" ]]; then
        printf 'dangerous PAX v2 action without assertion between actions in %s\n' "$pax_file" >&2
        printf 'previous line %s: %s\n' "$pending_line" "$pending_danger" >&2
        printf 'current: %s\n' "$line" >&2
        return 1
      fi
      pending_danger="$line"
      pending_line="$(line_number_for "$pax_file" "$raw_line")"
    fi
  done < "$pax_file"
}

test -f "$repo_root/pax/spec/PAX-V2.md"
test -f "$repo_root/pax/examples/full-install-v2.pax"

while IFS= read -r pax_file; do
  header_line="$(awk 'NF { print; exit }' "$pax_file")"
  if [[ "$header_line" =~ [Vv]2 ]]; then
    check_v2_file "$pax_file"
  fi
done < <(find "$repo_root/pax/examples" -maxdepth 1 -type f -name '*.pax' | sort)

while IFS= read -r pax_file; do
  if check_v2_file "$pax_file" >/dev/null 2>&1; then
    printf 'invalid PAX v2 fixture unexpectedly passed: %s\n' "$pax_file" >&2
    exit 1
  fi
done < <(find "$repo_root/pax/tests/v2-invalid" -maxdepth 1 -type f -name '*.pax' 2>/dev/null | sort)

printf 'PAX v2 check passed.\n'
