let url = "i18n/de.po"

var HttpClient = function() {
    this.get = function(aUrl, aCallback) {
        var anHttpRequest = new XMLHttpRequest();
        anHttpRequest.onreadystatechange = function() { 
            if (anHttpRequest.readyState == 4 && anHttpRequest.status == 200)
                aCallback(anHttpRequest.responseText);
        }

        anHttpRequest.open( "GET", aUrl, true );            
        anHttpRequest.send( null );
    }
}

var client = new HttpClient();
client.get(url, function(body) {  
  console.log(body)
  
  po = body.replace(/\\n/g, '');
  let lines = po.split('\n');
  
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
      if (lines[i+1].indexOf('msgstr') !== -1) {
        let msgstr = lines[i+1].split(' "')[1].replace(/\"/g, '')
        if (msgstr=="") msgstr=msgid
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
