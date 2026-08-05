const fs = require('fs');
const path = require('path');

function search(dir) {
    if (!fs.existsSync(dir)) return;
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            search(fullPath);
        } else if (fullPath.endsWith('.dart')) {
            const lines = fs.readFileSync(fullPath, 'utf8').split('\n');
            for (let i = 0; i < lines.length; i++) {
                const lower = lines[i].toLowerCase();
                if (lower.includes('raise') || lower.includes('camera') || lower.includes('participants') || lower.includes('leave')) {
                    fs.appendFileSync('find_output.txt', `${fullPath}:${i + 1}: ${lines[i]}\n`);
                }
            }
        }
    }
}

fs.writeFileSync('find_output.txt', '');
search('lib/screens/meeting');
