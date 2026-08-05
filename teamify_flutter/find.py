import os

def search(dir):
    for root, dirs, files in os.walk(dir):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    try:
                        lines = f.readlines()
                    except:
                        continue
                    for i, line in enumerate(lines):
                        lower = line.lower()
                        if 'raise' in lower or 'camera' in lower or 'participants' in lower or 'leave' in lower:
                            with open('find_out.txt', 'a', encoding='utf-8') as out:
                                out.write(f"{path}:{i+1}:{line}")

with open('find_out.txt', 'w', encoding='utf-8') as f:
    f.write('')
search('lib/screens/meeting')
