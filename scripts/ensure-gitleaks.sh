#!/bin/bash
# cspell: ignore shopt euxo
set -euo pipefail

DEBUG="${1:-false}"

if [[ "${DEBUG}" = "true" ]]
then
  set -x
fi

gitleaks_cmd=$(command -v gitleaks ~/.local/bin/gitleaks | head -1 || true)
arch="$(uname)_$(uname -m)"
platform=$(echo "$arch" | tr '[:upper:]' '[:lower:]' )
if [[ "$platform" =~ mingw.* || "$platform" =~ cygwin.* || "$platform" =~ msys.* ]]; then
    if [[ $PROCESSOR_ARCHITECTURE == "AMD64" ]]; then
        platform="windows_x64"
    elif [[ $PROCESSOR_ARCHITECTURE == "ARM64" ]]; then
        platform="windows_armv7"
    else
        echo "::error::Unsupported platform: $PROCESSOR_ARCHITECTURE"
        exit 4
    fi
    archive="zip"
else
    platform="${platform//aarch64/arm64}"
    platform="${platform//x86_64/x64}"
    archive="tar.gz"
fi

if [[ -n "$gitleaks_cmd" ]]; then
    version="$(gitleaks --version || true)"
    if [[ -n "$version" ]]; then
        echo "::notice::Detected ${gitleaks_cmd} version ${version} on ${platform}."
        exit 0
    fi
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gitleaks
        gitleaks_cmd=$(command -v gitleaks)
        version="$(gitleaks --version || true)"
    elif [[ "$OSTYPE" == "linux"* || "$OSTYPE" == "msys"* ]]; then
        max_attempts=10
        attempt=0
        while [[ $attempt -lt $max_attempts ]]; do
            # Not using curl+jq because jq is not available on Windows github runners
            version_tag="$(gh release view --repo gitleaks/gitleaks --json tagName -q .tagName)"
            version="${version_tag#v}"
            if [[ -n "$version" ]]; then
                break
            fi
            attempt=$((attempt + 1))
            delay=$((10 + attempt * 10))
            echo "::warning::Attempt $attempt failed to fetch version, retrying in $delay seconds. stdout: ${version_tag}"
            sleep $delay
        done
        mkdir -p ~/.local/bin
        if [[ "$OSTYPE" == "msys"* ]]; then
            tmp_file=$TEMP/gitleaks.zip
        else
            tmp_file=$(mktemp)
        fi
        curl -Lf -o "$tmp_file" "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_${platform}.${archive}"
        if [[ "$OSTYPE" == "msys"* ]]; then
            unzip -p "$tmp_file" gitleaks.exe > "$USERPROFILE\AppData\Local\Microsoft\WindowsApps\gitleaks.exe"
            gitleaks_cmd=~/.local/bin/gitleaks
        else
            tar xf "$tmp_file" -C ~/.local/bin/ gitleaks
            gitleaks_cmd=~/.local/bin/gitleaks
            chmod +x ~/.local/bin/gitleaks
        fi
        rm "$tmp_file"
    else
        echo "::error::Unsupported platform: $OSTYPE"
        exit 4
    fi
fi

if [[ -z "${version:-}" ]]; then
    echo "::error::Failed to fetch Gitleaks version after $max_attempts attempts."
    exit 3
fi
{
    echo "platform=$platform";
    echo "version=${version}";
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
echo "::notice::Detected ${gitleaks_cmd} version ${version} on ${platform}."
