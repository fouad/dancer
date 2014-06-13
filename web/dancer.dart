import 'dart:typed_data';
import 'dart:html';
import 'dart:web_audio';
import 'dart:math';
import 'dart:async';

CanvasRenderingContext2D dancer = null;
CanvasElement canvas = null;
HtmlElement status = null;
var rand = new Random();

var audioContext = new AudioContext();
var audioInput = null,
    realAudioInput = null,
    inputPoint = null;

String type;
WebSocket ws;

var zeroGain = null,
    analyserNode = null;

int canvasWidth() {
   return window.innerWidth;
}

int canvasHeight() {
  return window.innerHeight;
}

var lastTime = null;

var colors = ["36, 179, 96", "204, 51, 51", "44,133,211", "156,0,233", "151,207,58", "250,105,0", "60,87,118"];

// alternate red/blue colors
var flasher = false;

void flashAlert() {
  if (flasher) {
    dancer.fillStyle = "#4994B6";
  } else {
    dancer.fillStyle = "#FC0C4C";
  }
  
  flasher = !flasher;
  
  dancer.fillRect(0, 0, canvasWidth(), canvasHeight());
}

void renderAudio(time) {
  var SPACING = 3;
  var BAR_WIDTH = 1;
  
  if (type == "alert") {
    flashAlert();
    var timer = new Timer(const Duration(milliseconds: 100), () {
      renderAudio(0);
    });
    
    status.text = "QUIET QUIET QUIET";

    return;
  }
  
  // resize canvas to fit window
  dancer.canvas.width = canvasWidth();
  dancer.canvas.height = canvasHeight();

  var numBars = (canvasWidth() / SPACING).round();
  var freqByteData = new Uint8List(analyserNode.frequencyBinCount);

  analyserNode.getByteFrequencyData(freqByteData); 

  dancer.clearRect(0, 0, canvasWidth(), canvasHeight());
  
  dancer.fillStyle = '#F6D565';
  dancer.lineCap = 'round';
  var multiplier = (analyserNode.frequencyBinCount / numBars).floor();
  var avg = 0;
  
  var color = colors[rand.nextInt(colors.length)];

  // Draw rectangle for each frequency bin.
  for (var i = 0; i < numBars; ++i) {
    var magnitude = 0;
    var offset = ( i * multiplier ).floor();
    // gotta sum/average the block, or we miss narrow-bandwidth spikes
    for (var j = 0; j< multiplier; j++)
      magnitude += freqByteData[offset + j];
    
    magnitude = (magnitude / multiplier);
    
    avg += magnitude;
    
    // increase volatility of the bars
    if (magnitude > 0) {
      magnitude += magnitude * 1.5;
    }
    
    var magnitude2 = freqByteData[i * multiplier];
    
    dancer.fillStyle = "rgba($color,.75)";
    
    if (type == "bars") {
      dancer.fillRect(i * SPACING, canvasHeight(), BAR_WIDTH, -magnitude); 
    } else {
      var x = 10 + rand.nextInt(canvasWidth() - 10);
      
      dancer.beginPath();
      dancer.arc(x, canvasHeight() - i * 1.4, (magnitude / 15).round(), 0, PI * 2, true);
      dancer.closePath();
      dancer.fill(); 
    }
  }
  
  if (lastTime == null) {
    lastTime = time;
  } else {
    if (time - lastTime > 450) {
      lastTime = time;
      
      avg = (avg / numBars);
      
      String msg;
      
      status = querySelector("h1");
      
      if (avg < 40) {
        status.style.color = 'rgba(255,255,255,.65)';
        msg = "Turn the music back on";
      } else if (avg < 100) {
        var color = colors[0];
        status.style.color = 'rgba($color,.65)';
        msg = "Aite now we bumpin'";
      } else if (avg < 150) {
        var color = colors[1];
        status.style.color = 'rgba($color, .65)';
        msg  = "Yeah let's fucking rage";
      } else {
        var color = colors[1];
        status.style.color = 'rgba($color, .65)';
        msg  = "OH SHIT DAWG";
      }
      
      status.text = msg; 

    }
  }
  
  window.requestAnimationFrame(renderAudio);
}

var WS_URL = "";

void initSocket() {
  ws = new WebSocket('ws://' + WS_URL + '/ws');
  var data = "";
  
  ws.onOpen.listen((e) {
    print('Connected');
    ws.send('Hello from Dart!');
  });

  ws.onClose.listen((e) {
    print('Websocket closed');
  });

  ws.onError.listen((e) {
    print("Error connecting to ws");
  });

  ws.onMessage.listen((MessageEvent e) {
    type = e.data;
    print('Received message: ${e.data}');
  });
}

void handleStream(stream) {
  inputPoint = audioContext.createGain();

  realAudioInput = audioContext.createMediaStreamSource(stream);
  audioInput = realAudioInput;
  
  audioInput.connectNode(inputPoint);
  
  analyserNode = audioContext.createAnalyser();
  analyserNode.fftSize = 2048;
  inputPoint.connectNode( analyserNode );

  zeroGain = audioContext.createGain();
  zeroGain.gain.value = 0.0;

  inputPoint.connectNode( zeroGain );
  zeroGain.connectNode( audioContext.destination );
  
  window.requestAnimationFrame(renderAudio);
}

void main() {
  canvas = querySelector("#dancer");
  dancer = canvas.getContext("2d");
  
  initSocket();
  
  window.navigator.getUserMedia(audio: true).then(handleStream);
}