#!/usr/bin/env bash
set -Eeuo pipefail

create_checksums() {
    local backup_dir="$1"
    local checksum_file="${backup_dir}/SHA256SUMS.txt"
    (
        cd "$backup_dir"
        find . -maxdepth 1 -type f ! -name 'SHA256SUMS.txt' ! -name 'backup_meta.json' -printf '%P\0' \
            | sort -z \
            | xargs -0 sha256sum
    ) > "$checksum_file"
    chmod 600 "$checksum_file"
    log_success "Файл контрольных сумм создан: $checksum_file"
    printf '%s' "$checksum_file"
}

file_sha256() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

detect_os_name() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        printf '%s' "${PRETTY_NAME:-Linux}"
    else
        uname -s
    fi
}

create_backup_meta() {
    local backup_dir="$1"
    local ts="$2"
    local status="${3:-success}"
    local duration="${4:-0}"
    shift 4
    local files=("$@")
    local meta_file="${backup_dir}/backup_meta.json"
    local hostname_value
    hostname_value="$(hostname 2>/dev/null || echo unknown)"
    local os_value
    os_value="$(detect_os_name)"

    {
        echo "{"
        printf '  "app": "%s",\n' "$(json_escape "${APP_NAME:-Backup-S3}")"
        printf '  "version": "%s",\n' "$(json_escape "${APP_VERSION:-1.0.0}")"
        printf '  "profile": "%s",\n' "$(json_escape "${BACKUP_PROFILE_NAME:-default}")"
        printf '  "site_name": "%s",\n' "$(json_escape "${SITE_NAME:-}")"
        printf '  "site_dir": "%s",\n' "$(json_escape "${SITE_DIR:-}")"
        printf '  "db_enabled": %s,\n' "$(bool_true "${DB_ENABLED:-false}" && echo true || echo false)"
        printf '  "db_type": "%s",\n' "$(json_escape "${DB_TYPE:-}")"
        printf '  "db_name": "%s",\n' "$(json_escape "${DB_NAME:-}")"
        printf '  "backup_date": "%s",\n' "$(json_escape "$ts")"
        printf '  "hostname": "%s",\n' "$(json_escape "$hostname_value")"
        printf '  "os": "%s",\n' "$(json_escape "$os_value")"
        printf '  "s3_provider": "%s",\n' "$(json_escape "${S3_PROVIDER:-}")"
        printf '  "s3_endpoint": "%s",\n' "$(json_escape "${S3_ENDPOINT:-}")"
        printf '  "s3_bucket": "%s",\n' "$(json_escape "${S3_BUCKET:-}")"
        printf '  "s3_prefix": "%s",\n' "$(json_escape "${CURRENT_S3_TARGET:-}")"
        printf '  "storage_class": "%s",\n' "$(json_escape "${S3_STORAGE_CLASS:-}")"
        echo '  "files": ['
        local index=0
        local file
        local total="${#files[@]}"
        for file in "${files[@]}"; do
            [ -f "$file" ] || continue
            index=$((index + 1))
            local comma=","
            [ "$index" -ge "$total" ] && comma=""
            local name
            name="$(basename "$file")"
            local type="artifact"
            case "$name" in
                *.sql.gz|*.sql.gz.enc) type="database" ;;
                *files*.tar.gz|*files*.tar.gz.enc) type="site_files" ;;
                extra_paths*) type="extra_paths" ;;
                SHA256SUMS.txt) type="checksums" ;;
            esac
            echo "    {"
            printf '      "name": "%s",\n' "$(json_escape "$name")"
            printf '      "type": "%s",\n' "$type"
            printf '      "size_bytes": %s,\n' "$(file_size "$file")"
            printf '      "sha256": "%s"\n' "$(file_sha256 "$file")"
            printf '    }%s\n' "$comma"
        done
        echo "  ],"
        printf '  "status": "%s",\n' "$(json_escape "$status")"
        printf '  "duration_seconds": %s\n' "$duration"
        echo "}"
    } > "$meta_file"
    chmod 600 "$meta_file"
    log_success "Файл метаданных создан: $meta_file"
    printf '%s' "$meta_file"
}
