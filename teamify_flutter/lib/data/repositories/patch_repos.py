import os
import re

repo_dir = r"c:\Users\20111\Desktop\Teamify\teamify_flutter\lib\data\repositories"

for filename in os.listdir(repo_dir):
    if not filename.endswith("_repository.dart") or filename == "repository_helpers.dart":
        continue
    
    filepath = os.path.join(repo_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all methods in the repository class
    # Example: Future<ApiProject> getProject(String id) async {
    # Replace with: Future<ApiProject> getProject(String id, {CancelToken? cancelToken}) async {
    
    # Actually, it's easier to add cancelToken to _client calls.
    # _client.get('/api/projects', ...) -> _client.get('/api/projects', cancelToken: cancelToken, ...)
    
    # We need to make sure Dio is imported if we use CancelToken.
    if "import 'package:dio/dio.dart';" not in content:
        content = "import 'package:dio/dio.dart';\n" + content

    # Add {CancelToken? cancelToken} to method signatures
    # A bit hard to regex. Let's just do it for ProjectRepository and TaskRepository manually as examples if full automation is too risky.
    # But wait, the requirement is "all services/repositories".
    
    # Regex to find method signatures inside classes:
    # Future<Type> methodName(args) async {
    def repl_method(m):
        args = m.group(2)
        if "{" in args:
            # Already has named args
            if "cancelToken" not in args:
                args = args.replace("{", "{CancelToken? cancelToken, ")
        else:
            if args.strip():
                args = args + ", {CancelToken? cancelToken}"
            else:
                args = "{CancelToken? cancelToken}"
        return f"Future<{m.group(1)}> {m.group(3)}({args}) async {{"

    content = re.sub(r'Future<([^>]+)>\s+(\w+)\((.*?)\)\s*async\s*\{', repl_method, content)

    # Now add cancelToken to _client.xxx calls
    content = re.sub(r'_client\.get(<[^>]+>)?\(([^;]+)\)', r'_client.get\1(\2, cancelToken: cancelToken)', content)
    content = re.sub(r'_client\.post(<[^>]+>)?\(([^;]+)\)', r'_client.post\1(\2, cancelToken: cancelToken)', content)
    content = re.sub(r'_client\.patch(<[^>]+>)?\(([^;]+)\)', r'_client.patch\1(\2, cancelToken: cancelToken)', content)
    content = re.sub(r'_client\.put(<[^>]+>)?\(([^;]+)\)', r'_client.put\1(\2, cancelToken: cancelToken)', content)
    content = re.sub(r'_client\.delete(<[^>]+>)?\(([^;]+)\)', r'_client.delete\1(\2, cancelToken: cancelToken)', content)
    
    # Fix double cancelToken if present (e.g. data: {}, cancelToken: cancelToken, cancelToken: cancelToken)
    content = re.sub(r'(cancelToken:\s*cancelToken\s*,?\s*){2,}', r'cancelToken: cancelToken, ', content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done patching repositories.")
