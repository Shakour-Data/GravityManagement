#!/usr/bin/env python3
"""
Security Testing Script for GravityPM Backend
Tests common security vulnerabilities
"""

import asyncio
import aiohttp
import json
from typing import List, Dict, Any
from datetime import datetime

class SecurityTester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    async def test_sql_injection(self) -> Dict[str, Any]:
        """Test for SQL injection vulnerabilities"""
        print("🛡️ Testing SQL Injection vulnerabilities...")

        sql_payloads = [
            "' OR '1'='1",
            "'; DROP TABLE users; --",
            "' UNION SELECT * FROM users --",
            "admin' --",
            "1' OR '1' = '1"
        ]

        vulnerable_endpoints = []

        for payload in sql_payloads:
            # Test login endpoint
            data = {"username": payload, "password": "test"}
            try:
                async with self.session.post(f"{self.base_url}/auth/token", json=data) as response:
                    if response.status == 200:
                        vulnerable_endpoints.append({
                            "endpoint": "/auth/token",
                            "payload": payload,
                            "status": response.status
                        })
            except:
                pass

            # Test search endpoints
            try:
                async with self.session.get(f"{self.base_url}/projects?search={payload}") as response:
                    if response.status == 200:
                        text = await response.text()
                        if "error" not in text.lower():
                            vulnerable_endpoints.append({
                                "endpoint": "/projects",
                                "payload": payload,
                                "status": response.status
                            })
            except:
                pass

        return {
            "test_name": "SQL Injection",
            "vulnerable_endpoints": vulnerable_endpoints,
            "status": "PASS" if len(vulnerable_endpoints) == 0 else "FAIL"
        }

    async def test_xss(self) -> Dict[str, Any]:
        """Test for XSS vulnerabilities"""
        print("🛡️ Testing XSS vulnerabilities...")

        xss_payloads = [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "javascript:alert('XSS')",
            "<svg onload=alert('XSS')>",
            "'><script>alert('XSS')</script>"
        ]

        vulnerable_endpoints = []

        for payload in xss_payloads:
            # Test input fields that might reflect user input
            data = {"name": payload, "description": payload}
            try:
                async with self.session.post(f"{self.base_url}/projects", json=data) as response:
                    if response.status in [200, 201]:
                        text = await response.text()
                        if payload in text:
                            vulnerable_endpoints.append({
                                "endpoint": "/projects",
                                "payload": payload,
                                "status": response.status
                            })
            except:
                pass

        return {
            "test_name": "XSS",
            "vulnerable_endpoints": vulnerable_endpoints,
            "status": "PASS" if len(vulnerable_endpoints) == 0 else "FAIL"
        }

    async def test_authentication_bypass(self) -> Dict[str, Any]:
        """Test for authentication bypass vulnerabilities"""
        print("🛡️ Testing Authentication bypass...")

        bypass_attempts = [
            {"username": "admin", "password": ""},  # Empty password
            {"username": "", "password": "admin"},  # Empty username
            {"username": "admin", "password": "wrong"},  # Wrong password
            {"username": "wrong", "password": "admin"},  # Wrong username
        ]

        successful_bypasses = []

        for attempt in bypass_attempts:
            try:
                async with self.session.post(f"{self.base_url}/auth/token", json=attempt) as response:
                    if response.status == 200:
                        successful_bypasses.append({
                            "attempt": attempt,
                            "status": response.status
                        })
            except:
                pass

        return {
            "test_name": "Authentication Bypass",
            "successful_bypasses": successful_bypasses,
            "status": "PASS" if len(successful_bypasses) == 0 else "FAIL"
        }

    async def test_rate_limiting(self) -> Dict[str, Any]:
        """Test rate limiting implementation"""
        print("🛡️ Testing Rate Limiting...")

        # Make multiple rapid requests
        tasks = []
        for i in range(50):  # More than typical rate limit
            task = self.session.post(f"{self.base_url}/auth/token",
                                   json={"username": "test", "password": "test"})
            tasks.append(task)

        responses = await asyncio.gather(*tasks, return_exceptions=True)

        rate_limited_responses = 0
        for response in responses:
            if not isinstance(response, Exception) and hasattr(response, 'status'):
                if response.status == 429:  # Too Many Requests
                    rate_limited_responses += 1

        return {
            "test_name": "Rate Limiting",
            "total_requests": len(tasks),
            "rate_limited_responses": rate_limited_responses,
            "rate_limiting_effective": rate_limited_responses > 0,
            "status": "PASS" if rate_limited_responses > 0 else "WARNING"
        }

    async def test_security_headers(self) -> Dict[str, Any]:
        """Test security headers"""
        print("🛡️ Testing Security Headers...")

        try:
            async with self.session.get(f"{self.base_url}/docs") as response:
                headers = dict(response.headers)

                security_headers = {
                    "X-Content-Type-Options": headers.get("X-Content-Type-Options"),
                    "X-Frame-Options": headers.get("X-Frame-Options"),
                    "X-XSS-Protection": headers.get("X-XSS-Protection"),
                    "Content-Security-Policy": headers.get("Content-Security-Policy"),
                    "Strict-Transport-Security": headers.get("Strict-Transport-Security")
                }

                missing_headers = [k for k, v in security_headers.items() if not v]

                return {
                    "test_name": "Security Headers",
                    "present_headers": {k: v for k, v in security_headers.items() if v},
                    "missing_headers": missing_headers,
                    "status": "PASS" if len(missing_headers) == 0 else "WARNING"
                }
        except Exception as e:
            return {
                "test_name": "Security Headers",
                "error": str(e),
                "status": "ERROR"
            }

    async def run_security_test_suite(self) -> Dict[str, Any]:
        """Run comprehensive security test suite"""
        print("🔒 Starting GravityPM Security Test Suite")
        print("=" * 60)

        test_results = {}

        # Run all security tests
        test_results["sql_injection"] = await self.test_sql_injection()
        test_results["xss"] = await self.test_xss()
        test_results["auth_bypass"] = await self.test_authentication_bypass()
        test_results["rate_limiting"] = await self.test_rate_limiting()
        test_results["security_headers"] = await self.test_security_headers()

        # Generate summary report
        print("\n" + "=" * 60)
        print("📊 SECURITY TEST SUMMARY")
        print("=" * 60)

        passed_tests = sum(1 for result in test_results.values() if result["status"] == "PASS")
        failed_tests = sum(1 for result in test_results.values() if result["status"] == "FAIL")
        warning_tests = sum(1 for result in test_results.values() if result["status"] == "WARNING")

        print(f"Total Security Tests: {len(test_results)}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {failed_tests}")
        print(f"Warnings: {warning_tests}")

        # Detailed results
        print("\n🔍 Detailed Results:")
        for test_name, result in test_results.items():
            status_emoji = {
                "PASS": "✅",
                "FAIL": "❌",
                "WARNING": "⚠️",
                "ERROR": "🔥"
            }.get(result["status"], "❓")

            print(f"   {status_emoji} {test_name}: {result['status']}")

            if result["status"] == "FAIL" and "vulnerable_endpoints" in result:
                print(f"      Vulnerable endpoints: {len(result['vulnerable_endpoints'])}")

            if result["status"] == "FAIL" and "successful_bypasses" in result:
                print(f"      Successful bypasses: {len(result['successful_bypasses'])}")

        # Overall assessment
        if failed_tests == 0:
            overall_status = "✅ SECURE"
        elif failed_tests < 3:
            overall_status = "⚠️ REQUIRES ATTENTION"
        else:
            overall_status = "❌ CRITICAL VULNERABILITIES"

        print(f"\n🏆 Overall Security Status: {overall_status}")

        return test_results

async def main():
    """Main function to run security tests"""
    async with SecurityTester() as tester:
        results = await tester.run_security_test_suite()

        # Save results to file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"security_test_results_{timestamp}.json"

        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)

        print(f"\n💾 Results saved to: {filename}")

if __name__ == "__main__":
    asyncio.run(main())
