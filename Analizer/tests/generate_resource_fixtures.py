"""Generate clearly labelled synthetic UI cases; never mix them with evidence."""
import argparse
from pathlib import Path
import sys
from test_oclumon_formats import block

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from analizador import ejecutar_caso_completo

parser = argparse.ArgumentParser()
parser.add_argument('output')
args = parser.parse_args()
root = Path(args.output)
for count in (1, 2, 4):
    target = root / f'fixture-{count}'
    source = target / 'fuentes-sinteticas'
    source.mkdir(parents=True, exist_ok=True)
    for number in range(1, count + 1):
        host = f'fixture-host-{number:02d}'
        text = ''.join(block(host=host, stamp=stamp, cpu=str(cpu+number), counter=str(counter))
                       for stamp,cpu,counter in [('2026-10-05 10.30.00',10,50),
                                                 ('2026-10-05 10.30.05',20,53),
                                                 ('2026-10-05 11.30.00',30,2)])
        (source / f'{host}.txt').write_text(text,encoding='utf-8')
    result = ejecutar_caso_completo(str(source),str(target/'case.duckdb'),
                                   log_cb=lambda _:None,salida=str(target/'informe_incidente.html'))
    print(count,result['ruta_informe'],flush=True)
