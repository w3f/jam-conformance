import os
import json
import glob
import statistics
import argparse

# --- CONFIGURATION ---
SESSIONS_DIR = "./sessions"
BENCHMARK_GOAL = 1000000  # 1 Million STEPS total
# ---------------------

def get_trace_count_from_files(trace_dir):
    """
    Fallback: Scans the trace directory for the highest numbered .bin file.
    Example: 00099919.bin -> 99919
    """
    if not os.path.exists(trace_dir):
        return 0

    max_block = 0
    try:
        files = os.listdir(trace_dir)
    except OSError:
        return 0

    for f in files:
        if f.endswith(".bin") and f != "report.bin":
            try:
                # remove .bin and convert to int
                num = int(f.replace(".bin", ""))
                if num > max_block:
                    max_block = num
            except ValueError:
                continue

    return max_block

def analyze_session(session_path):
    trace_id = os.path.basename(session_path)
    report_path = os.path.join(session_path, "report", "report.json")
    trace_dir = os.path.join(session_path, "trace")

    data = {
        "id": trace_id,
        "target_name": "UNKNOWN",
        "steps": 0,
        "imported": 0,
        "source": "UNKNOWN",
        "error": None
    }

    # 1. Try to read the JSON Report
    if os.path.exists(report_path):
        try:
            with open(report_path, 'r') as f:
                report = json.load(f)
                
                stats = report.get("stats", {})
                
                # --- KEY METRIC: STEPS ---
                data["steps"] = stats.get("steps", 0)
                # Context metric: Imported
                data["imported"] = stats.get("imported", 0)
                
                # Grab Target Name (app_name)
                data["target_name"] = report.get("target", {}).get("info", {}).get("app_name", "UNKNOWN")
                
                # Check for error
                err_obj = report.get("error")
                if isinstance(err_obj, dict):
                    data["error"] = list(err_obj.values())[0] if err_obj else None
                else:
                    data["error"] = err_obj
                
                data["source"] = "Report"
                return data
        except Exception as e:
            data["error"] = f"JSON Parse Error: {str(e)}"

    # 2. Fallback: Count trace files if report failed
    # We use file count as a proxy for steps if the real log is missing
    if os.path.exists(trace_dir):
        highest_block = get_trace_count_from_files(trace_dir)
        if highest_block > 0:
            data["imported"] = highest_block
            data["steps"] = highest_block  # Proxy value
            data["source"] = "Trace (Fallback)"
            if not data["error"]:
                data["error"] = "No Report Found"

    return data

def main():
    # Setup Argument Parser
    parser = argparse.ArgumentParser(description="Analyze fuzzing session results.")
    parser.add_argument("--target", type=str, help="Filter results by Target Name (e.g., 'JavaJAM')", default=None)
    args = parser.parse_args()

    if not os.path.exists(SESSIONS_DIR):
        print(f"Error: Directory '{SESSIONS_DIR}' not found.")
        return

    # Find all session directories
    session_paths = [f.path for f in os.scandir(SESSIONS_DIR) if f.is_dir()]
    session_paths.sort()

    results = []
    filtered_results = []

    print(f"{'TRACE ID':<25} | {'TARGET':<15} | {'STEPS':<10} | {'IMPORTED':<8} | {'SOURCE':<18} | {'STATUS/ERROR'}")
    print("-" * 110)

    for path in session_paths:
        res = analyze_session(path)
        results.append(res)

        # --- FILTER LOGIC ---
        if args.target:
            if args.target.lower() not in res['target_name'].lower():
                continue
        
        filtered_results.append(res)

        # Formatting output
        error_msg = str(res['error']) if res['error'] else "✅ Success"
        if len(error_msg) > 30: error_msg = error_msg[:27] + "..."
        
        target_display = res['target_name']
        if len(target_display) > 15: target_display = target_display[:12] + "..."

        print(f"{res['id']:<25} | {target_display:<15} | {res['steps']:<10,} | {res['imported']:<8,} | {res['source']:<18} | {error_msg}")

    print("-" * 110)

    # --- STATISTICS & BENCHMARK ---
    if not filtered_results:
        print("No sessions found matching criteria.")
        return

    # Summing STEPS now, not imports
    total_steps = sum(r['steps'] for r in filtered_results)
    total_imports = sum(r['imported'] for r in filtered_results)
    
    step_counts = [r['steps'] for r in filtered_results]

    avg_steps = statistics.mean(step_counts)
    min_steps = min(step_counts)
    max_steps = max(step_counts)

    # Calculate progress percentage based on STEPS
    progress = (total_steps / BENCHMARK_GOAL) * 100

    print("\n📊 --- FINAL SUMMARY (METRIC: STEPS) ---")
    if args.target:
        print(f"Filter Active:      {args.target}")
    print(f"Total Runs Analyzed:    {len(filtered_results)}")
    print(f"Total Steps Executed:   {total_steps:,} / {BENCHMARK_GOAL:,}")
    print(f"Total Blocks Imported:  {total_imports:,} (Secondary)")
    print(f"Progress:               {progress:.2f}%")
    print("-" * 30)
    print(f"Average Steps/Run:      {avg_steps:,.2f}")
    print(f"Min Steps (Worst):      {min_steps:,}")
    print(f"Max Steps (Best):       {max_steps:,}")
    print("-" * 30)

    if total_steps >= BENCHMARK_GOAL:
        print("🎉 PASSED: 1 Million Steps Benchmark Achieved!")
    else:
        missing = BENCHMARK_GOAL - total_steps
        print(f"⚠️  FAILED: Missing {missing:,} steps to reach goal.")

if __name__ == "__main__":
    main()
