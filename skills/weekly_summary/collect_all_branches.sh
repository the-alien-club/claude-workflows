#!/bin/bash
# Collect commits from ALL branches (including feature branches) for the week

MONDAY="$1"
SUNDAY="$2"
OUTPUT_DIR="/tmp/weekly_commits_by_repo"

mkdir -p "$OUTPUT_DIR"

REPOS=(
  "web-app"
  "workers"
  "data-pipelines"
  "data-cluster"
  "data-cluster-operator"
  "data-cluster-helm"
  "k8s-charts"
  "skupper-gateway"
  "MCPs/mcp-base"
  "MCPs/mcp-boilerplate"
  "MCPs/mcp-datacluster"
  "MCPs/mcp-openaire"
)

echo "📦 Collecting commits from all branches for week: $MONDAY to $SUNDAY"
echo ""

for repo in "${REPOS[@]}"; do
  if [ -d "$repo/.git" ]; then
    echo "🔍 Processing: $repo"

    OUTPUT_FILE="$OUTPUT_DIR/${repo//\//_}.txt"

    cd "$repo" || continue

    # Get all branches (local and remote) that have commits in this week
    echo "=== REPOSITORY: $repo ===" > "$OUTPUT_FILE"
    echo "=== COLLECTION DATE: $(date) ===" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Get unique list of all branches with activity this week
    ACTIVE_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ | \
      while read branch; do
        if git log "$branch" --since="$MONDAY 00:00:00" --until="$SUNDAY 23:59:59" --oneline 2>/dev/null | grep -q .; then
          echo "$branch"
        fi
      done | sort -u)

    if [ -z "$ACTIVE_BRANCHES" ]; then
      echo "=== NO ACTIVITY THIS WEEK ===" >> "$OUTPUT_FILE"
      cd - > /dev/null
      continue
    fi

    echo "=== ACTIVE BRANCHES ===" >> "$OUTPUT_FILE"
    echo "$ACTIVE_BRANCHES" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Collect detailed commits from all active branches
    echo "=== COMMITS ===" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Use --all to get commits from all branches, --since/--until for time range
    git log --all --since="$MONDAY 00:00:00" --until="$SUNDAY 23:59:59" \
      --format="COMMIT_START%n%H|%an|%ae|%ad|%s%n%b%nCOMMIT_END%n" \
      --date=iso >> "$OUTPUT_FILE"

    COMMIT_COUNT=$(grep -c "COMMIT_START" "$OUTPUT_FILE")
    echo "   ✅ $COMMIT_COUNT commits collected"

    cd - > /dev/null
  else
    echo "   ⚠️  $repo not found"
  fi
done

echo ""
echo "✅ All commits collected to: $OUTPUT_DIR"
echo ""
echo "📊 Summary:"
for file in "$OUTPUT_DIR"/*.txt; do
  repo=$(basename "$file" .txt)
  commits=$(grep -c "COMMIT_START" "$file" 2>/dev/null || echo "0")
  echo "   $repo: $commits commits"
done
