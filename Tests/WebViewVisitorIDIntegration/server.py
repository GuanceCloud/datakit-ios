from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
from pathlib import Path
import json,urllib.parse,threading
condition=threading.Condition();release=threading.Event();held=0
root=Path(__file__).parent
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  global held
  url=urllib.parse.urlsplit(self.path)
  if url.path=='/hold/prepare':
   with condition:held=0;release.clear()
   data=b'{}';kind='application/json'
  elif url.path=='/hold/wait':
   with condition:condition.wait_for(lambda:held>=2,timeout=10)
   data=json.dumps({'held':held}).encode();kind='application/json'
  elif url.path=='/hold/release':
   release.set();data=b'{}';kind='application/json'
  elif url.path=='/sdk.js':
   bundle=urllib.parse.parse_qs(self.headers.get('Referer','').split('?',1)[-1]).get('bundle',['full'])[0]
   package='browser-rum' if bundle=='full' else 'browser-rum-slim'
   data=(root/package/'package/bundle'/('dataflux-rum.js' if bundle=='full' else 'dataflux-rum-slim.js')).read_bytes();kind='application/javascript'
  elif url.path.startswith('/api/'):
   item={'path':self.path,'headers':{k.lower():v for k,v in self.headers.items()}}
   with (root/'requests.jsonl').open('a') as file:file.write(json.dumps(item)+'\n')
   if urllib.parse.parse_qs(url.query).get('hold')==['1']:
    with condition:held+=1;condition.notify_all()
    release.wait(timeout=15)
   data=json.dumps(item).encode();kind='application/json'
  elif url.path=='/':data=(root/'page.html').read_bytes();kind='text/html'
  else:data=b'{}';kind='application/json'
  self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(data)
 def do_POST(self):
  data=self.rfile.read(int(self.headers.get('Content-Length','0')))
  with (root/'intake.jsonl').open('a') as file:file.write(json.dumps({'path':self.path,'body':data.decode(errors='replace')})+'\n')
  self.send_response(200);self.end_headers();self.wfile.write(b'{}')
server=ThreadingHTTPServer(('127.0.0.1',18763),Handler)
print('Listening on 127.0.0.1:18763',flush=True);server.serve_forever()
