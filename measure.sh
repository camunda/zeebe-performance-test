#!/bin/sh
set -o errexit

url=https://monitoring.googleapis.com/v1/projects/zeebe-io/location/global/prometheus/api/v1/query
token=$(gcloud auth print-access-token)

# Query helpers
percentile() {
    echo "histogram_quantile($1, $2)"
}
stddev() {
    echo "stddev_over_time(($1)[5m:])"
}

run_query() {
    until result=$(curl -s $url -d "query=$1" -H "Authorization: Bearer $token" | jq '.data.result[0].value[1] | tonumber')
    do
        echo "Failed to query, retrying..."
        sleep 5
    done
    echo "$result"
}

wait_for_query_value() {
    result=0

    until [ "$result" -eq 1 ]
    do
        sleep 30
        value=$(curl -s $url -d "query=$1" -H "Authorization: Bearer $token" | jq '.data.result[0].value[1] | tonumber')
        result=$(echo "$value $2 $3" | bc)
        printf "\r %g %s %g: %s" "$value" "$2" "$3" "$result"
    done
    printf "\n"
}

# Query definitions
latency="sum by (le) (rate(zeebe_process_instance_execution_time_bucket{namespace=\"$BENCHMARK_NAME\"}[5m]))"
throughput="sum(rate(zeebe_element_instance_events_total{namespace=\"$BENCHMARK_NAME\",  action=\"completed\", type=\"PROCESS\"}[5m]))"

# Wait until metrics are stable
stable_latency="$(stddev "$(percentile 0.99 "$latency")")"
stable_throughput="$(stddev "$throughput")"

echo "Waiting for minimal throughput"
wait_for_query_value "$throughput" \> 5 

echo "Waiting for stable process instance execution times (stddev < 0.5)"
wait_for_query_value "$stable_latency" \< 0.5

echo "Waiting for stable throughput (stddev < 0.5)"
wait_for_query_value "$stable_throughput" \< 0.5

# Measure
process_latency_99=$(run_query "$(percentile 0.99 "$latency")")
process_latency_90=$(run_query "$(percentile 0.90 "$latency")")
process_latency_50=$(run_query "$(percentile 0.50 "$latency")")

throughput_avg=$(run_query "$throughput")

if [ -n "$GITHUB_STEP_SUMMARY" ]
then
    echo "**Process Instance Execution Time**: p99=$process_latency_99 p90=$process_latency_90 p50=$process_latency_50" >> "$GITHUB_STEP_SUMMARY"
    echo "**Throughput**: $throughput_avg PI/s" >> "$GITHUB_STEP_SUMMARY"
else
    echo "Process Instance Execution Time: p99=$process_latency_99 p90=$process_latency_90 p50=$process_latency_50"
    echo "Throughput: $throughput_avg PI/s"
fi
