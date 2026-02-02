import os
import json
import glob
import statistics

# --- CONFIGURATION ---
SESSIONS_DIR = "./sessions"
BENCHMARK_GOAL = 1000000  # 1 Million blocks total
EXPECTED_RUNS = 10        # We expect 10 parallel runners
# ---------------------

def get_trace_count_from_files(trace_dir):
    """
    Fallback: Scans the trace directory for the highest numbered .bin file.
    Example: 00099919.bin -> 99919
    """
    if not os.path.exists(trace_dir):
        return 0
    
    max_block = 0
    files = os.listdir(trace_dir)
    
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
        "imported": 0,
        "source": "UNKNOWN",
        "error": None
    }

    # 1. Try to read the JSON Report
    if os.path.exists(report_path):
        try:
            with open(report_path, 'r') as f:
                report = json.load(f)
                # Grab imported count from 'stats'
                data["imported"] = report.get("stats", {}).get("imported", 0)
                data["error"] = report.get("error")
                data["source"] = "Report"
                return data
        except Exception as e:
            data["error"] = f"JSON Parse Error: {str(e)}"

    # 2. Fallback: Count trace files if report failed or doesn't exist
    if os.path.exists(trace_dir):
        highest_block = get_trace_count_from_files(trace_dir)
        if highest_block > 0:
            data["imported"] = highest_block
            data["source"] = "Trace (Fallback)"
            if not data["error"]: 
                data["error"] = "No Report Found"
    
    return data

def main():
    if not os.path.exists(SESSIONS_DIR):
        print(f"Error: Directory '{SESSIONS_DIR}' not found.")
        return

    # Find all session directories
    session_paths = [f.path for f in os.scandir(SESSIONS_DIR) if f.is_dir()]
    session_paths.sort()

    results = []
    
    print(f"{'TRACE ID':<25} | {'IMPORTED':<10} | {'SOURCE':<18} | {'STATUS/ERROR'}")
    print("-" * 85)

    for path in session_paths:
        res = analyze_session(path)
        results.append(res)
        
        # Formatting status
        error_msg = str(res['error']) if res['error'] else "✅ Success"
        if len(error_msg) > 30: error_msg = error_msg[:27] + "..."
        
        print(f"{res['id']:<25} | {res['imported']:<10,} | {res['source']:<18} | {error_msg}")

    print("-" * 85)

    # --- STATISTICS & BENCHMARK ---
    total_imported = sum(r['imported'] for r in results)
    counts = [r['imported'] for r in results]
    
    if not counts:
        print("No sessions found.")
        return

    avg_blocks = statistics.mean(counts)
    min_blocks = min(counts)
    max_blocks = max(counts)
    
    # Calculate progress percentage
    progress = (total_imported / BENCHMARK_GOAL) * 100
    
    print("\n📊 --- FINAL SUMMARY ---")
    print(f"Total Runs Analyzed:   {len(results)}")
    print(f"Total Blocks Imported: {total_imported:,} / {BENCHMARK_GOAL:,}")
    print(f"Progress:              {progress:.2f}%")
    print("-" * 30)
    print(f"Average per Run:       {avg_blocks:,.2f}")
    print(f"Min Blocks (Worst):    {min_blocks:,}")
    print(f"Max Blocks (Best):     {max_blocks:,}")
    print("-" * 30)
    
    if total_imported >= BENCHMARK_GOAL:
        print("🎉 PASSED: 1 Million Benchmark Achieved!")
    else:
        missing = BENCHMARK_GOAL - total_imported
        print(f"⚠️  FAILED: Missing {missing:,} blocks to reach goal.")

if __name__ == "__main__":
    main()
