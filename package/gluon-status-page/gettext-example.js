let url = "i18n/de.po"

fetch(url)
  .then((res) => {
  return res.body.getReader();
})
  .then((reader) => {
  return reader.read();
})
  .then((stream) => {
  let decoder = new TextDecoder();
  let body = decoder.decode(stream.value || new Uint8Array);
  return body
})
  .then((body) => {
  let text = body.replace(/\\n/g, '');
  let lines = text.split('\n');

  console.log(text)
  
  let arr = []
  let obj = {}
  
  for (let i = 0; i < lines.length; i++) {

    // key:value pairs
    if (lines[i].indexOf(':') !== -1) {
      let line = lines[i].replace(/"/g, '');
      let pair = line.split(':');
      if (pair.length) {
        obj[pair[0]] = pair[1].trim();
      }
    }


    // msgid
    if (lines[i].indexOf('msgid') !== -1) {
      let msgobj = {};
      let msgid = lines[i].split(' "')[1].replace(/\"/g, '');
      msgobj.msgid = msgid;

      // msgstr
      if (lines[i].indexOf('msgid') !== -1) {
        let msgstr = lines[i].split(' "')[1].replace(/\"/g, '');
        msgobj.msgstr = msgstr;
      }

      arr.push(msgobj);
      
    }

  }
  
  arr.push(obj)

  
  document.getElementById('output-source')
    .innerHTML = body
  
  document.getElementById('output-js')
    .innerHTML = JSON.stringify(arr, null, 2);
});
