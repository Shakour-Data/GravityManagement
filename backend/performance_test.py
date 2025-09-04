#!/usr/bin/env python3
"""
Performance Testing Script for GravityPM Backend
Tests API endpoints under various load conditions
"""

import asyncio
import aiohttp
import time
import statistics
from typing import List, Dict, Any
import json
from datetime import datetime

class PerformanceTester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    async def make_request(self, method: str, endpoint: str, data: Dict = None, headers: Dict = None) -> Dict[str, Any]:
        """Make a single HTTP request and measure response time"""
        url = f"{self.base_url}{endpoint}"
        start_time = time.time()

        try:
            if method.upper() == "GET":
                async with self.session.get(url, headers=headers) as response:
                    response_time = time.time() - start_time
                    return {
                        "status": response.status,
                        "response_time": response_time,
                        "success": response.status < 400
                    }
            elif method.upper() == "POST":
                async with self.session.post(url, json=data, headers=headers) as response:
                    response_time = time.time() - start_time
                    return {
                        "status": response.status,
                        "response_time": response_time,
                        "success": response.status < 400
                    }
            elif method.upper() == "PUT":
                async with self.session.put(url, json=data, headers=headers) as response:
                    response_time = time.time() - start_time
                    return {
                        "status": response.status,
                        "response_time": response_time,
                        "success": response.status < 400
                    }
            elif method.upper() == "DELETE":
                async with self.session.delete(url, headers=headers) as response:
                    response_time = time.time() - start_time
                    return {
                        "status": response.status,
                        "response_time": response_time,
                        "success": response.status < 400
                    }
        except Exception as e:
            response_time = time.time() - start_time
            return {
                "status": 0,
                "response_time": response_time,
                "success": False,
                "error": str(e)
            }

    async def run_load_test(self, method: str, endpoint: str, num_requests: int = 100,
                          concurrent_users: int = 10, data: Dict = None, headers: Dict = None) -> Dict[str, Any]:
        """Run load test with specified parameters"""

        print(f"🚀 Starting load test: {method} {endpoint}")
        print(f"📊 Requests: {num_requests}, Concurrent users: {concurrent_users}")

        start_time = time.time()
        results = []

        # Create semaphore to limit concurrent requests
        semaphore = asyncio.Semaphore(concurrent_users)

        async def make_request_with_semaphore():
            async with semaphore:
                result = await self.make_request(method, endpoint, data, headers)
                results.append(result)
                return result

        # Execute all requests concurrently
        tasks = [make_request_with_semaphore() for _ in range(num_requests)]
        await asyncio.gather(*tasks)

        total_time = time.time() - start_time

        # Calculate statistics
        response_times = [r["response_time"] for r in results]
        successful_requests = [r for r in results if r["success"]]

        stats = {
            "total_requests": num_requests,
            "successful_requests": len(successful_requests),
            "failed_requests": len(results) - len(successful_requests),
            "success_rate": len(successful_requests) / num_requests * 100,
            "total_time": total_time,
            "requests_per_second": num_requests / total_time,
            "avg_response_time": statistics.mean(response_times),
            "min_response_time": min(response_times),
            "max_response_time": max(response_times),
            "p95_response_time": statistics.quantiles(response_times, n=20)[18],  # 95th percentile
            "p99_response_time": statistics.quantiles(response_times, n=100)[98]  # 99th percentile
        }

        print("📈 Test Results:")
        print(f"   Success Rate: {stats['success_rate']:.2f}%")
        print(f"   Requests/sec: {stats['requests_per_second']:.2f}")
        print(f"   Avg Response Time: {stats['avg_response_time']:.3f}s")
        print(f"   P95 Response Time: {stats['p95_response_time']:.3f}s")
        print(f"   P99 Response Time: {stats['p99_response_time']:.3f}s")

        return stats

    async def run_performance_test_suite(self):
        """Run comprehensive performance test suite"""
        print("🧪 Starting GravityPM Performance Test Suite")
        print("=" * 60)

        test_results = {}

        # Test 1: Authentication endpoints
        print("\n🔐 Testing Authentication Endpoints")
        test_results["auth_login"] = await self.run_load_test(
            "POST", "/auth/token",
            num_requests=50, concurrent_users=5,
            data={"username": "testuser", "password": "testpass"}
        )

        # Test 2: Project endpoints
        print("\n📁 Testing Project Endpoints")
        test_results["projects_get"] = await self.run_load_test(
            "GET", "/projects",
            num_requests=100, concurrent_users=10
        )

        # Test 3: Task endpoints
        print("\n✅ Testing Task Endpoints")
        test_results["tasks_get"] = await self.run_load_test(
            "GET", "/tasks",
            num_requests=100, concurrent_users=10
        )

        # Test 4: GitHub integration
        print("\n🔗 Testing GitHub Integration")
        test_results["github_repos"] = await self.run_load_test(
            "GET", "/github/repos",
            num_requests=30, concurrent_users=3
        )

        # Generate summary report
        print("\n" + "=" * 60)
        print("📊 PERFORMANCE TEST SUMMARY")
        print("=" * 60)

        total_requests = sum(result["total_requests"] for result in test_results.values())
        total_successful = sum(result["successful_requests"] for result in test_results.values())
        overall_success_rate = total_successful / total_requests * 100

        print(f"Total Endpoints Tested: {len(test_results)}")
        print(f"Total Requests: {total_requests}")
        print(f"Overall Success Rate: {overall_success_rate:.2f}%")
        print(f"Average RPS: {sum(result['requests_per_second'] for result in test_results.values()) / len(test_results):.2f}")

        # Performance benchmarks check
        print("\n🎯 Performance Benchmarks:")
        for endpoint, result in test_results.items():
            status = "✅ PASS" if result["avg_response_time"] < 2.0 else "❌ FAIL"
            print(f"   {endpoint}: {result['avg_response_time']:.3f}s {status}")

        return test_results

async def main():
    """Main function to run performance tests"""
    async with PerformanceTester() as tester:
        results = await tester.run_performance_test_suite()

        # Save results to file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"performance_test_results_{timestamp}.json"

        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)

        print(f"\n💾 Results saved to: {filename}")

if __name__ == "__main__":
    asyncio.run(main())
