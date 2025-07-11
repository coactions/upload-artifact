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
platform="${platform//aarch64/arm64}"
platform="${platform//x86_64/x64}"

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
    elif [[ "$OSTYPE" == "linux"* ]]; then
        max_attempts=10
        attempt=0
        while [[ $attempt -lt $max_attempts ]]; do
            version_tag="$(curl --retry 5 -s -f https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r .name || true)"
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
        tmp_file=$(mktemp)
        curl -Lfs -o "$tmp_file" "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_${platform}.tar.gz"
        tar xf "$tmp_file" -C ~/.local/bin/gitleaks gitleaks
        rm "$tmp_file"
        chmod +x ~/.local/bin/gitleaks
        gitleaks_cmd=~/.local/bin/gitleaks
    elif [[ "$OSTYPE" == "msys"* ]]; then
        winget install gitleaks
        gitleaks --version
    else
        echo "::error::Unsupported platform: $OSTYPE"
        exit 4
    fi
fi

if [[ -z "$version" ]]; then
    echo "::error::Failed to fetch Gitleaks version after $max_attempts attempts."
    exit 3
fi
{
    echo "platform=$platform";
    echo "version=${version}";
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
echo "::notice::Detected ${gitleaks_cmd} version ${version} on ${platform}."
