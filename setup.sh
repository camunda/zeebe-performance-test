#!/bin/sh
set -o errexit

kubectl delete ns "$BENCHMARK_NAME"
helm repo add zeebe-benchmark https://zeebe-io.github.io/benchmark-helm
helm install "$BENCHMARK_NAME" \
    zeebe-benchmark/zeebe-benchmark \
    --namespace="$BENCHMARK_NAME" --create-namespace

if [ -n "$GITHUB_STEP_SUMMARY" ]
then
    {
        echo "Deployed **$BENCHMARK_NAME** with custom values: "
        echo '```yaml'
        helm -n "$BENCHMARK_NAME" get values "$BENCHMARK_NAME" -o yaml
        echo '```'

        echo "<details>"
        echo "<summary>All benchmark values</summary>"
        echo ""
        echo '```yaml'
        helm -n "$BENCHMARK_NAME" get values "$BENCHMARK_NAME" -o yaml -a
        echo '```'
        echo "</details>"
    }  >> "$GITHUB_STEP_SUMMARY"
else
    helm -n "$BENCHMARK_NAME" get values "$BENCHMARK_NAME" -o yaml
fi