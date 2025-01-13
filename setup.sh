#!/bin/sh
set -o errexit

kubectl delete ns "$BENCHMARK_NAME" || true
helm repo add zeebe-benchmark https://camunda.github.io/zeebe-benchmark-helm
helm install "$BENCHMARK_NAME" \
    zeebe-benchmark/zeebe-benchmark \
    --namespace="$BENCHMARK_NAME" --create-namespace \
    $HELM_ARGS
kubectl -n "$BENCHMARK_NAME" rollout status statefulset "$BENCHMARK_NAME"-zeebe
kubectl -n "$BENCHMARK_NAME" create job --from=cronjob/leader-balancer manual-rebalancing-"$(date +%s)"

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
fi

if [ -n "$GITHUB_OUTPUT" ]
then
    {
        echo "summary_markdown<<EOF"
        echo "Deployed to **$BENCHMARK_NAME**"
        echo '```yaml'
        helm -n "$BENCHMARK_NAME" get values "$BENCHMARK_NAME" -o yaml
        echo '```'
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
    {
        echo "summary_slack<<EOF"
        echo "Measured performance of *$BENCHMARK_NAME*"
        helm -n "$BENCHMARK_NAME" get values "$BENCHMARK_NAME" -o yaml
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
fi

helm -n "$BENCHMARK_NAME" get values "$BENCHMARK_NAME" -o yaml
