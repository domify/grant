#!/usr/bin/env bash
# port/review.sh <commit>... : per commit, compare `# it:` markers and assertions with upstream
for c in "$@"; do
  echo "=== $c $(git log -1 --format=%s $c)"
  git show --stat --format= $c | tail -n +1 | grep -v manifest
  for t in $(git show --name-only --format= $c | grep '_test\.iyi$'); do
    src=$(ruby -ryaml -e 'e=YAML.load_file("port/manifest.yml"); e=e["entries"]||e if e.is_a?(Hash); def walk(x,t) ; x.each{|y| return y["source"] if y["target"]==t; (r=walk(y["children"],t)) and return r if y["children"]}; nil; end; puts walk(e,ARGV[0])' "$t" 2>/dev/null)
    [[ -f $src ]] || { echo "  $t: source?"; continue; }
    ui=$(grep -cE '^\s*it "' $src); ti=$(git show $c:$t | grep -c '# it:')
    us=$(grep -cE '\.should|expect_raises' $src); ta=$(git show $c:$t | grep -cE '^\s*assert|expect_error|assert_')
    echo "  $t <- ${src#crystal-upstream/}: it $ti/$ui assert $ta/$us"
  done
done
