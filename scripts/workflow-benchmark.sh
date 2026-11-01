#!/usr/bin/env bash
# Paired Loom vs single-agent benchmark harness: init, validate, summarize.
# Requires Bash 3.2+ and jq 1.6+. Launches nothing and measures nothing itself.
set -eu

SCHEMA="loom-workflow-benchmark/v1"
WORKLOADS="doc-fix localized-bug feature security architecture"
MODES="loom single-agent"
METRICS='["wallClockSeconds","agentCount","tokenInput","tokenOutput","estimatedCostUsd","commits","reviewRounds","defectsIntroduced","defectsCaught","humanInterventions"]'
INTS='["agentCount","tokenInput","tokenOutput","commits","reviewRounds","defectsIntroduced","defectsCaught","humanInterventions"]'
PROV='["task","startingCommit","acceptanceCriteria","testCommands","seededDefects","detectionProcedure","client","model","reasoning","host","pricingSource","pricingDate","executionOrder"]'
EVID='["commitIds","testOutcomes","paths","defects","interventions","deviations"]'

usage() {
    echo "usage: ${0##*/} init|validate|summarize <output-dir>" >&2
    exit 2
}

die() {
    echo "$*" >&2
    exit 1
}

# Template record: incomplete, timestamps null, metrics null, supporting fields empty.
template() {
    jq -n --arg w "$1" --arg m "$2" --argjson mets "$METRICS" --argjson prov "$PROV" \
        --argjson evid "$EVID" '
        {workload: $w, mode: $m,
         timestamps: {start: null, end: null, interruptions: []}}
        + ([$mets[] | {(.): null}] | add)
        + {status: "incomplete", unknownReasons: {},
           provenance: ([$prov[] | {(.): ""}] | add),
           evidence: ([$evid[] | {(.): []}] | add)}'
}

init() {
    local dir=$1 w m
    [ -e "$dir" ] && die "exists: $dir already exists"
    mkdir -p "$(dirname "$dir")"
    mkdir "$dir" || die "exists: cannot create $dir"
    mkdir "$dir/records"
    for w in $WORKLOADS; do
        for m in $MODES; do
            template "$w" "$m" >"$dir/records/$w--$m.json"
            printf 'records/%s--%s.json\n' "$w" "$m"
        done
    done | jq -R . | jq -s --arg s "$SCHEMA" '{schemaVersion: $s, records: .}' >"$dir/manifest.json"
}

# Prints the first problem found in one record, or nothing when it is valid.
# Args: workload mode. Reads the record on stdin.
# shellcheck disable=SC2016  # jq program, not shell
RECORD_CHECK='
def nstr: type == "string" and length > 0;
def ts: type == "string"
    and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
    and (. as $s | try ($s | fromdateiso8601 | todateiso8601 == $s) catch false);
def exact($k): type == "object" and ((keys | sort) == ($k | sort));
def complete: .status == "success" or .status == "failure";
def checks:
  if (. | exact($mets + ["workload","mode","timestamps","status","unknownReasons","provenance","evidence"])) | not
  then "invalid: record keys" else
  (if .workload != $w then "invalid: workload" else empty end),
  (if .mode != $m then "invalid: mode" else empty end),
  (if (.status | IN("incomplete","success","failure")) | not then "invalid: status" else empty end),
  ($mets[] as $k | .[$k] as $v
    | select($v != null and (($v | type) != "number" or $v < 0
        or (($k | IN($ints[])) and $v != ($v | floor))))
    | "invalid: " + $k),
  (.timestamps | if (exact(["start","end","interruptions"])) | not then "invalid: timestamps"
    else (.start, .end | select(. != null and (ts | not)) | "invalid: timestamps"),
      (select(.start != null and .end != null and ((.start | ts) and (.end | ts))
         and (.start | fromdateiso8601) > (.end | fromdateiso8601)) | "invalid: timestamps order"),
      (if (.interruptions | type) != "array" then "invalid: timestamps.interruptions"
       else .interruptions[] | select((type == "object" and (.description | nstr)
         and (.seconds | type) == "number" and .seconds >= 0) | not)
         | "invalid: timestamps.interruptions" end)
    end),
  (.unknownReasons | if type != "object" or ([.[] | nstr] | all | not) then "invalid: unknownReasons" else empty end),
  (.provenance | if (exact($prov) and ([.[] | type == "string"] | all)) | not then "invalid: provenance" else empty end),
  (.evidence | if (exact($evid) and ([.[] | type == "array" and ([.[] | nstr] | all)] | all)) | not
    then "invalid: evidence" else empty end),
  (if complete then
    (if .timestamps.start == null or .timestamps.end == null then "invalid: timestamps" else empty end),
    (.unknownReasons as $u | $mets[] as $k | select(.[$k] == null and (($u[$k] // "") | nstr | not))
      | "unknown reason: " + $k),
    (.provenance | to_entries[] | select(.value | nstr | not) | "provenance: " + .key),
    (.evidence | ("testOutcomes", "paths") as $k | select(.[$k] | length == 0) | "evidence: " + $k)
   else empty end)
  end;
first(try checks catch "invalid: record shape") // empty
'

check_record() {
    jq -r --arg w "$2" --arg m "$3" --argjson mets "$METRICS" --argjson ints "$INTS" \
        --argjson prov "$PROV" --argjson evid "$EVID" "$RECORD_CHECK" "$1"
}

validate() {
    local dir=$1 manifest="$1/manifest.json" rel w m err file seen=""
    [ -f "$manifest" ] || die "missing: $manifest"
    jq -e . "$manifest" >/dev/null 2>&1 || die "invalid: $manifest is malformed JSON"
    jq -e --arg s "$SCHEMA" '
        type == "object" and ((keys | sort) == ["records", "schemaVersion"])
        and .schemaVersion == $s and (.records | type == "array")
        and ([.records[] | type == "string"] | all)' "$manifest" >/dev/null ||
        die "invalid: $manifest schema or keys"
    while IFS= read -r rel; do
        case " $seen " in *" $rel "*) die "duplicate: pair $rel" ;; esac
        seen="$seen $rel"
        w=${rel#records/}
        w=${w%%--*}
        m=${rel#records/"$w"--}
        m=${m%.json}
        case " $WORKLOADS " in *" $w "*) ;; *) die "invalid: workload in $rel" ;; esac
        case " $MODES " in *" $m "*) ;; *) die "invalid: mode in $rel" ;; esac
        [ "$rel" = "records/$w--$m.json" ] || die "invalid: path $rel"
    done < <(jq -r '.records[]' "$manifest")
    for w in $WORKLOADS; do
        for m in $MODES; do
            case " $seen " in *" records/$w--$m.json "*) ;; *) die "missing: pair $w--$m" ;; esac
        done
    done
    for rel in $seen; do
        file="$dir/$rel"
        [ -f "$file" ] || die "missing: $rel"
        jq -e . "$file" >/dev/null 2>&1 || die "invalid: $rel is malformed JSON"
        w=${rel#records/}
        w=${w%%--*}
        m=${rel#records/"$w"--}
        m=${m%.json}
        err=$(check_record "$file" "$w" "$m")
        [ -z "$err" ] || die "$err ($rel)"
    done
}

summarize() {
    local dir=$1 w
    validate "$dir"
    for w in $WORKLOADS; do
        jq -s -r --arg w "$w" --argjson mets "$METRICS" '
            def done: .status != "incomplete";
            def show: if . == null then "unknown" else tostring end;
            (map(select(.workload == $w and .mode == "loom"))[0]) as $l
            | (map(select(.workload == $w and .mode == "single-agent"))[0]) as $s
            | $w,
              ($mets[] as $k
               | "  \($k): loom=\($l[$k] | show) single-agent=\($s[$k] | show) delta="
                 + (if ($l | done) and ($s | done) and $l[$k] != null and $s[$k] != null
                    then ($l[$k] - $s[$k] | tostring) else "unknown" end))' \
            "$dir/records/$w--loom.json" "$dir/records/$w--single-agent.json"
    done
}

[ $# -eq 2 ] || usage
case "$1" in
init) init "$2" ;;
validate) validate "$2" ;;
summarize) summarize "$2" ;;
*) usage ;;
esac
