# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**Do not open public issues for security vulnerabilities.**

Please report security vulnerabilities by emailing security@hyperpolymath.dev

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will acknowledge receipt within 48 hours and provide a detailed response within 7 days.

## Security Considerations

This library is a FFI bridge between Idris 2 and other languages. Security considerations:

1. **Memory Safety**: All memory operations go through controlled allocation functions
2. **Type Safety**: Type conversions are checked at compile time where possible
3. **ABI Stability**: Version checking prevents incompatible library combinations
4. **No Arbitrary Code Execution**: The bridge only marshals data, not code
