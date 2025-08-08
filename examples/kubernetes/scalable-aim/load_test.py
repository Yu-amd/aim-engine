#!/usr/bin/env python3
"""
Load Testing Script for Scalable AIM
This script generates load to test the horizontal pod autoscaler.
"""

import requests
import json
import time
import threading
import statistics
from typing import List, Dict
from concurrent.futures import ThreadPoolExecutor, as_completed

class LoadTester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'LoadTester/1.0'
        })
        self.results = []
    
    def health_check(self) -> bool:
        """Check if the AIM is healthy."""
        try:
            response = self.session.get(f"{self.base_url}/health", timeout=10)
            return response.status_code == 200
        except requests.RequestException:
            return False
    
    def send_request(self, request_id: int) -> Dict:
        """Send a single request and return timing information."""
        messages = [
            {"role": "user", "content": f"Request {request_id}: What is the capital of France? Please provide a detailed answer."}
        ]
        
        payload = {
            "model": "Qwen/Qwen2.5-7B-Instruct",
            "messages": messages,
            "max_tokens": 200,
            "temperature": 0.7,
            "stream": False
        }
        
        start_time = time.time()
        try:
            response = self.session.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                timeout=60
            )
            end_time = time.time()
            
            if response.status_code == 200:
                return {
                    'request_id': request_id,
                    'status': 'success',
                    'response_time': end_time - start_time,
                    'status_code': response.status_code,
                    'tokens': len(response.json().get('choices', [{}])[0].get('message', {}).get('content', '').split())
                }
            else:
                return {
                    'request_id': request_id,
                    'status': 'error',
                    'response_time': end_time - start_time,
                    'status_code': response.status_code,
                    'error': response.text
                }
        except requests.RequestException as e:
            end_time = time.time()
            return {
                'request_id': request_id,
                'status': 'error',
                'response_time': end_time - start_time,
                'error': str(e)
            }
    
    def run_load_test(self, num_requests: int, concurrent_requests: int, delay: float = 0.1):
        """Run a load test with specified parameters."""
        print(f"🚀 Starting load test: {num_requests} requests, {concurrent_requests} concurrent")
        print(f"   Base URL: {self.base_url}")
        print(f"   Delay between batches: {delay}s")
        print("-" * 60)
        
        # Check health first
        if not self.health_check():
            print("❌ AIM is not healthy. Cannot run load test.")
            return
        
        print("✅ AIM is healthy, starting load test...")
        
        start_time = time.time()
        self.results = []
        
        with ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
            # Submit all requests
            futures = [
                executor.submit(self.send_request, i)
                for i in range(num_requests)
            ]
            
            # Collect results as they complete
            completed = 0
            for future in as_completed(futures):
                result = future.result()
                self.results.append(result)
                completed += 1
                
                if completed % 10 == 0:
                    print(f"   Completed: {completed}/{num_requests}")
                
                # Add delay between batches to create sustained load
                if completed % concurrent_requests == 0:
                    time.sleep(delay)
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # Analyze results
        self.analyze_results(total_time)
    
    def analyze_results(self, total_time: float):
        """Analyze and display test results."""
        print("\n📊 Load Test Results")
        print("=" * 60)
        
        # Basic statistics
        successful_requests = [r for r in self.results if r['status'] == 'success']
        failed_requests = [r for r in self.results if r['status'] == 'error']
        
        print(f"Total Requests: {len(self.results)}")
        print(f"Successful: {len(successful_requests)}")
        print(f"Failed: {len(failed_requests)}")
        print(f"Success Rate: {len(successful_requests)/len(self.results)*100:.1f}%")
        print(f"Total Time: {total_time:.2f}s")
        print(f"Requests per Second: {len(self.results)/total_time:.2f}")
        
        if successful_requests:
            response_times = [r['response_time'] for r in successful_requests]
            print(f"\nResponse Time Statistics:")
            print(f"  Average: {statistics.mean(response_times):.3f}s")
            print(f"  Median: {statistics.median(response_times):.3f}s")
            print(f"  Min: {min(response_times):.3f}s")
            print(f"  Max: {max(response_times):.3f}s")
            print(f"  Std Dev: {statistics.stdev(response_times):.3f}s")
            
            # Percentiles
            sorted_times = sorted(response_times)
            p50 = sorted_times[int(len(sorted_times) * 0.5)]
            p90 = sorted_times[int(len(sorted_times) * 0.9)]
            p95 = sorted_times[int(len(sorted_times) * 0.95)]
            p99 = sorted_times[int(len(sorted_times) * 0.99)]
            
            print(f"\nResponse Time Percentiles:")
            print(f"  50th: {p50:.3f}s")
            print(f"  90th: {p90:.3f}s")
            print(f"  95th: {p95:.3f}s")
            print(f"  99th: {p99:.3f}s")
        
        if failed_requests:
            print(f"\n❌ Failed Requests ({len(failed_requests)}):")
            error_counts = {}
            for req in failed_requests:
                error = req.get('error', 'Unknown error')
                error_counts[error] = error_counts.get(error, 0) + 1
            
            for error, count in error_counts.items():
                print(f"  {error}: {count} times")

def main():
    print("🚀 Scalable AIM Load Tester")
    print("=" * 50)
    
    # Configuration
    base_url = "http://localhost:8000"
    
    # Test scenarios
    scenarios = [
        {"name": "Light Load", "requests": 10, "concurrent": 2, "delay": 0.5},
        {"name": "Medium Load", "requests": 50, "concurrent": 5, "delay": 0.2},
        {"name": "Heavy Load", "requests": 100, "concurrent": 10, "delay": 0.1},
        {"name": "Stress Test", "requests": 200, "concurrent": 20, "delay": 0.05},
    ]
    
    tester = LoadTester(base_url)
    
    print("Available test scenarios:")
    for i, scenario in enumerate(scenarios, 1):
        print(f"  {i}. {scenario['name']}: {scenario['requests']} requests, {scenario['concurrent']} concurrent")
    
    print("\nNote: Make sure port forwarding is set up:")
    print("  kubectl port-forward svc/scalable-aim 8000:8000 -n aim-engine")
    print()
    
    try:
        choice = input("Choose scenario (1-4) or 'custom': ").strip()
        
        if choice.lower() == 'custom':
            requests = int(input("Number of requests: "))
            concurrent = int(input("Concurrent requests: "))
            delay = float(input("Delay between batches (seconds): "))
            scenario = {"name": "Custom", "requests": requests, "concurrent": concurrent, "delay": delay}
        else:
            scenario = scenarios[int(choice) - 1]
        
        print(f"\n🎯 Running {scenario['name']} scenario...")
        tester.run_load_test(
            num_requests=scenario['requests'],
            concurrent_requests=scenario['concurrent'],
            delay=scenario['delay']
        )
        
        print(f"\n💡 To monitor scaling, run:")
        print(f"  kubectl get hpa -n aim-engine -w")
        print(f"  kubectl get pods -n aim-engine -w")
        
    except (ValueError, IndexError):
        print("❌ Invalid choice")
    except KeyboardInterrupt:
        print("\n👋 Load test interrupted")

if __name__ == "__main__":
    main() 