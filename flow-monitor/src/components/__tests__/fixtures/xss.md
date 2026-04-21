# XSS fixture

This file intentionally contains three XSS attack vectors to verify that
DOMPurify strips each one before the HTML reaches the DOM.

## Vector (a) — raw script block

<script>alert("xss")</script>

## Vector (b) — inline event handler

<a href="https://example.com" onclick="alert(1)">click me</a>

## Vector (c) — javascript: URL

<a href="javascript:alert(1)">click me</a>
