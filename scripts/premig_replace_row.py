import csv

# Dateien
table_file = "ascii_table.txt"
csv_file = "values.csv"

# 1. ASCII-Tabelle einlesen
with open(table_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

if len(lines) < 3:
    print("❌ Tabelle muss mindestens 3 Zeilen haben.")
    exit(1)

header, data_line, footer = lines[0], lines[1], lines[2]

# 2. CSV-Werte einlesen (erste Zeile)
with open(csv_file, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    csv_values = next(reader)

# 3. Spalten im Datenbereich erkennen
parts = data_line.split('│')
new_parts = [parts[0]]  # linker Rand

# 4. Ersetzen, solange CSV-Werte vorhanden sind
for i, part in enumerate(parts[1:-1]):  # Spalteninhalte, ohne Rahmen
    if i < len(csv_values):
        value = csv_values[i].strip()
        padded = value.center(len(part))[:len(part)]  # exakt passender Text
        new_parts.append(padded)
    else:
        new_parts.append(part)  # nicht überschreiben

new_parts.append(parts[-1])  # rechter Rand

# 5. Neue Zeile zusammenbauen
new_data_line = '│'.join(new_parts).rstrip() + '\n'

# 6. Datei überschreiben
with open(table_file, 'w', encoding='utf-8') as f:
    f.write(header)
    f.write(new_data_line)
    f.write(footer)

print(f"✅ Werte aus '{csv_file}' wurden in '{table_file}' ersetzt.")

