import os
import re

service_dir = r"c:\Users\20111\Desktop\Teamify\teamify_flutter\lib\services"

for filename in os.listdir(service_dir):
    if not filename.endswith("_service.dart") or filename == "app_services.dart":
        continue
    
    filepath = os.path.join(service_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    if "import 'package:dio/dio.dart';" not in content:
        content = "import 'package:dio/dio.dart';\n" + content

    # Regex to find method signatures inside classes that return Future<ApiResult<...>>
    # Future<ApiResult<Type>> methodName(args) => 
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
        return f"Future<{m.group(1)}> {m.group(3)}({args}) =>"

    content = re.sub(r'Future<([^>]+)>\s+(\w+)\((.*?)\)\s*=>', repl_method, content)

    # Add cancelToken to _repo calls.
    # We'll just replace _repo.methodName(args) with _repo.methodName(args, cancelToken: cancelToken)
    # But it's risky to do all of them blindly. We can do:
    # _repo.(\w+)\((.*?)\) -> _repo.\1(\2, cancelToken: cancelToken)
    
    # We should avoid adding it if it's already there
    def repl_repo(m):
        func = m.group(1)
        args = m.group(2)
        if "cancelToken: cancelToken" in args:
            return m.group(0)
        if args.strip() == "":
            return f"_repo.{func}(cancelToken: cancelToken)"
        else:
            # check if it ends with a comma
            if args.strip().endswith(","):
                return f"_repo.{func}({args} cancelToken: cancelToken)"
            else:
                return f"_repo.{func}({args}, cancelToken: cancelToken)"

    # We need a proper parser for nested parens, but regex might work for simple cases.
    content = re.sub(r'_repo\.(\w+)\(([^)]*)\)', repl_repo, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done patching services.")
