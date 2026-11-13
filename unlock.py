#!/usr/bin/env python3
"""
Standalone TR-069 CWMP Responder for Jio Set-Top Box (JMSD200 / JMSD200A).
Replaces Docker + MongoDB + GenieACS inside unrooted Termux on port 7547.
Sends Device.JioSTB.USB.USBDebugging = true in an atomic single-parameter
session and closes cleanly with 204 No Content so adbd starts immediately.
"""
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = {"phase": 0, "step": 0, "cwmp_ns": "urn:dslforum-org:cwmp-1-0"}


class CWMPUnlockHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def send_xml(self, code, body_str, extra_headers=None):
        data = body_str.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", 'text/xml; charset="utf-8"')
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "keep-alive")
        if extra_headers:
            for k, v in extra_headers.items():
                self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def send_204(self):
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8", errors="replace")

        ns_m = re.search(r'xmlns:cwmp="([^"]+)"', raw)
        if ns_m:
            STATE["cwmp_ns"] = ns_m.group(1)
        id_m = re.search(r"<(?:\w+:)?ID[^>]*>(.*?)</(?:\w+:)?ID>", raw)
        req_id = id_m.group(1) if id_m else "1"
        ns = STATE["cwmp_ns"]

        # 1. Reply to TR-069 Inform
        if "Inform" in raw and "InformResponse" not in raw:
            print("[+] Jio Box connected! Sending InformResponse...")
            STATE["step"] = 1
            inform_resp = (
                f'<?xml version="1.0" encoding="UTF-8"?>'
                f'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cwmp="{ns}">'
                f'<soapenv:Header><cwmp:ID soapenv:mustUnderstand="1">{req_id}</cwmp:ID></soapenv:Header>'
                f"<soapenv:Body><cwmp:InformResponse><MaxEnvelopes>1</MaxEnvelopes></cwmp:InformResponse></soapenv:Body>"
                f"</soapenv:Envelope>"
            )
            self.send_xml(200, inform_resp, {"Set-Cookie": "session=jiostb; Path=/"})
            return

        # 2. On Empty POST, send RPC
        if length == 0 and STATE["step"] == 1:
            STATE["step"] = 2
            if STATE["phase"] == 0:
                print("[->] Phase 1: Sending ONLY Device.JioSTB.USB.USBDebugging = true (clean atomic session)...")
                xml = (
                    f'<?xml version="1.0" encoding="UTF-8"?>'
                    f'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
                    f'xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" '
                    f'xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
                    f'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                    f'xmlns:cwmp="{ns}">'
                    f'<soapenv:Header><cwmp:ID soapenv:mustUnderstand="1">2</cwmp:ID></soapenv:Header>'
                    f"<soapenv:Body><cwmp:SetParameterValues>"
                    f'<ParameterList soap-enc:arrayType="cwmp:ParameterValueStruct[1]">'
                    f"<ParameterValueStruct>"
                    f"<Name>Device.JioSTB.USB.USBDebugging</Name>"
                    f'<Value xsi:type="xsd:boolean">true</Value>'
                    f"</ParameterValueStruct>"
                    f"</ParameterList><ParameterKey></ParameterKey>"
                    f"</cwmp:SetParameterValues></soapenv:Body></soapenv:Envelope>"
                )
                self.send_xml(200, xml)
                return
            else:
                print("[->] Phase 2: Sending Device.JioSTB.FOTA.Disable = true...")
                xml = (
                    f'<?xml version="1.0" encoding="UTF-8"?>'
                    f'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
                    f'xmlns:soap-enc="http://schemas.xmlsoap.org/soap/encoding/" '
                    f'xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
                    f'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                    f'xmlns:cwmp="{ns}">'
                    f'<soapenv:Header><cwmp:ID soapenv:mustUnderstand="1">2</cwmp:ID></soapenv:Header>'
                    f"<soapenv:Body><cwmp:SetParameterValues>"
                    f'<ParameterList soap-enc:arrayType="cwmp:ParameterValueStruct[2]">'
                    f"<ParameterValueStruct>"
                    f"<Name>Device.JioSTB.FOTA.Disable</Name>"
                    f'<Value xsi:type="xsd:string">true</Value>'
                    f"</ParameterValueStruct>"
                    f"<ParameterValueStruct>"
                    f"<Name>Device.JioSTB.FOTA.DowngradeEnable</Name>"
                    f'<Value xsi:type="xsd:string">true</Value>'
                    f"</ParameterValueStruct>"
                    f"</ParameterList><ParameterKey></ParameterKey>"
                    f"</cwmp:SetParameterValues></soapenv:Body></soapenv:Envelope>"
                )
                self.send_xml(200, xml)
                return

        # 3. Close cleanly with 204 No Content so JioTR069Client commits & starts adbd (:5555)
        if "SetParameterValuesResponse" in raw:
            if STATE["phase"] == 0:
                print("\n[★★★] CLEAN SESSION COMPLETE: USBDebugging = true APPLIED & CLOSED WITH 204! [★★★]")
                print("[★★★] Wireless ADB (:5555) is now OPEN! Run: ./post_unlock.sh <TV_IP> [★★★]\n")
                STATE["phase"] = 1
            else:
                print("\n[★★★] FOTA.Disable = true APPLIED & CLOSED WITH 204! [★★★]\n")
                STATE["phase"] = 0
            self.send_204()
            return

        if "Fault" in raw:
            print("[!] CWMP Fault received:", raw)
            STATE["phase"] = 0
            self.send_204()
            return

        self.send_204()


if __name__ == "__main__":
    print("[*] Standalone JioSTB CWMP Unlock Server listening on 127.0.0.1:7547...")
    ThreadingHTTPServer(("127.0.0.1", 7547), CWMPUnlockHandler).serve_forever()
