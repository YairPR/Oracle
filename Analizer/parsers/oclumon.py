"""Storage facade for the shared legacy/section-CSV OCLUMON model."""
from parsers.base import BaseParser, LogType


class OclumonParser(BaseParser):
    log_type = LogType.OCLUMON

    def __init__(self):
        self.ultimo_diagnostico = None
        self.seen_metrics = {}

    def parse(self, file_path: str) -> list:
        """One full CHM read; storage and episodes share the normalized samples."""
        from core.episode_engine import parse_oclumon_file
        self.ultimo_normalizado = parse_oclumon_file(file_path)
        samples, diag, _ = self.ultimo_normalizado
        self.ultimo_diagnostico = diag
        self.lectura_perfil = {"lectura_seg": diag.get("lectura_seg", 0.0)}
        import json
        from datetime import timezone
        rows=[]
        for sample in samples:
            dt=sample['clock']
            stamp=dt.astimezone(timezone.utc).replace(tzinfo=None) if dt.tzinfo else dt
            domain=dt.strftime('%z') if dt.tzinfo else 'unknown'
            for metric,value in sample['telemetria']:
                key=(sample['node'], stamp, domain, metric)
                if key in self.seen_metrics:
                    if self.seen_metrics[key] != value:
                        diag.setdefault('conflicts', []).append({'metric':metric,'line':sample['line'],
                            'resolution':'first observation retained','original_value':value})
                    continue
                self.seen_metrics[key]=value
                rows.append({'timestamp':stamp,'nodo':sample['node'],'fuente':'oclumon',
                    'metrica_o_error':metric,'valor':value,
                    'detalles':json.dumps({'source':sample['source'],'block_line':sample['line'],
                                          'original_clock':sample['clock_raw'],'zone':domain})})
        return rows
