import os
print("Running find2.py...")
found = False
for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            try:
                with open(os.path.join(root, f), 'r', encoding='utf-8') as file:
                    for i, line in enumerate(file):
                        if 'raise' in line.lower() or 'leave' in line.lower() or 'camera' in line.lower():
                            print(f"{f}:{i}: {line.strip()}")
                            found = True
            except: pass
print("Done.")
