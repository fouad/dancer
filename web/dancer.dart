//names of things nucleus, grid, spiralcircle, mind, bars, circles, circlegrid

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
  //  type = "mind";
  // resize canvas to fit window
  dancer.canvas.width = canvasWidth();
  dancer.canvas.height = canvasHeight();

  var freqByteData = new Uint8List(analyserNode.frequencyBinCount);

  analyserNode.getByteFrequencyData(freqByteData);
  
  var avg = 0;
  var numElements;
  
  var color = colors[rand.nextInt(colors.length)];
  if (type == 'bars' || type == "circles") {
    var numElements = (canvasWidth() / SPACING).round();
    dancer.clearRect(0, 0, canvasWidth(), canvasHeight());
    
    dancer.fillStyle = '#F6D565';
    dancer.lineCap = 'round';
    var multiplier = (analyserNode.frequencyBinCount / numElements).floor();
    var avg = 0;
    // Draw rectangle for each frequency bin.
    for (var i = 0; i < numElements; ++i) {
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
        dancer.arc(x, canvasHeight() - i * 1.8, (magnitude / 15).round(), 0, PI * 2, true);
        dancer.closePath();
        dancer.fill(); 
      }
    }
  } else {
    var size;
    if (type == "circlegrid") {
      size = 8;
      numElements = size * size;
    } else if (type == "nucleus") {
      numElements = 256;
    } else if (type == "grid") {
      numElements = 32;
    } else {
      numElements = 16;
    }
    
    if (type == "mind" || type == "spiralcircle") {
      dancer.lineWidth = 5;
    }
    dancer.clearRect(0, 0, canvasWidth(), canvasHeight());
        
    dancer.fillStyle = '#F6D565';
    dancer.lineCap = 'round';
    var multiplier = (analyserNode.frequencyBinCount / numElements).floor();
    freqByteData = freqByteData.sublist(0, (freqByteData.length/2).floor());
    for (var i = 0; i < freqByteData.length; i += (freqByteData.length/numElements).floor()) {
      dancer.fillStyle = "rgba($color,.75)";
      dancer.strokeStyle = "rgba($color,.75)";
      var magnitude = 0;
      // gotta sum/average the block, or we miss narrow-bandwidth spikes
      for (var j = 0; j< freqByteData.length/numElements; j++)
        magnitude += freqByteData[i + j];
            
      magnitude = (magnitude / multiplier);
            
      avg += magnitude;
      
      if (type == "circlegrid") {
        dancer.beginPath();
        var xR = ((rand.nextInt(magnitude.round()+1) - magnitude/2).round())/2;
        var yR = ((rand.nextInt(magnitude.round()+1) - magnitude/2).round())/2;
        var x = (i / (freqByteData.length/numElements) % size) * canvasWidth()/size + canvasWidth()/size/2;
        var y = canvasHeight() - (i / (freqByteData.length/numElements) / size).floor() * canvasHeight()/size + canvasWidth()/size/2;
        dancer.arc(x + xR, y + yR, (magnitude / 2 * log(i+1)/log(10)).round(), 0, 2 * PI, true);
        dancer.closePath();
        dancer.fill();
      } else if (type == 'nucleus'){
        var sX = (canvasWidth() / 2).round();
        var sY = (canvasHeight() / 2).round();
        dancer.moveTo(sX, sY);
        var degree = 360 * ((i+1) / freqByteData.length);
        var fX = sX + (cos(degree) * magnitude * 4);
        var fY = sY + (sin(degree) * magnitude * 4);
        dancer.lineTo(fX,fY);
        dancer.stroke(); 
        dancer.beginPath();
        dancer.arc(fX, fY, (magnitude / 10 * log(i+1)/log(10)).round(), 0, 2 * PI, true);
        dancer.closePath();
        dancer.stroke();
        //dancer.fill();
      } else if (type == "spiralcircle") {
        var xR = rand.nextInt(10) - 5;
        var yR = rand.nextInt(10) - 5;
        dancer.beginPath();
        dancer.arc(canvasWidth()/2 + xR, canvasHeight()/2 + yR, magnitude * 5, 0, 2 * PI, true);
        dancer.closePath();
        dancer.stroke();
      } else if (type == 'mind') {
        var xR = rand.nextInt(50) - 25;
        var yR = rand.nextInt(50) - 25;
        dancer.beginPath();
        dancer.arc(canvasWidth()/2 + xR, canvasHeight()/2 + yR, 200 + magnitude * 2, 0, 2 * PI, true);
        dancer.closePath();
        dancer.stroke();
      } else if (type == 'grid') {
        var sHX, sHY, sVX, sVY, fHX, fHY, fVX, fVY;
        sHX = 0;
        fHX = canvasWidth();
        sVY = 0;
        fVY = canvasHeight();
        sHY = magnitude * 3;
        fHY = magnitude * 3;
        sVX = magnitude * 3;
        fVX = magnitude * 3;
        if (i > freqByteData.length / 2) {
          dancer.moveTo(sHX, sHY);
          dancer.lineTo(fHX, fHY);
          dancer.moveTo(sHX, canvasHeight() - sHY);
          dancer.lineTo(fHX, canvasHeight() - fHY);
        } else {
          dancer.moveTo(sVX, sVY);
          dancer.lineTo(fVX, fVY);
          dancer.moveTo(canvasWidth() - sVX, sVY);
          dancer.lineTo(canvasWidth() - fVX, fVY);
        }
        dancer.stroke();
      } else {
        var sX, sY, cX1, cY1, cX2, cY2, fX, fY;
        if (i > freqByteData.length / 2) {
          sX = 0;
          sY = canvasHeight() / 2;
          dancer.moveTo(sX, sY);
          cX1 = canvasWidth() / 4 - magnitude / 32;
          cY1 = canvasHeight() / 2 - magnitude * 8;
          cX2 = canvasWidth() / 4 * 3 + magnitude / 32;
          cY2 = canvasHeight() / 2 + magnitude * 8;
          fX = canvasWidth();
          fY = canvasHeight() / 2;
          dancer.bezierCurveTo(cX1, cY1, cX2, cY2, fX, fY);
          dancer.moveTo(sX, sY);
          dancer.bezierCurveTo(cX1, cY2, cX2, cY1, fX, fY);
        } else {
          sX = canvasWidth() / 2;
          sY = canvasHeight() / 8;
          dancer.moveTo(sX, sY);
          cX1 = canvasWidth() / 2 - magnitude * 4;
          cY1 = canvasHeight() / 4;
          cX2 = canvasWidth() / 2 + magnitude * 4;
          cY2 = canvasHeight() / 4 * 3;
          fX = canvasWidth() / 2;
          fY = canvasHeight() / 8 * 7;
          dancer.bezierCurveTo(cX1, cY1, cX2, cY2, fX, fY);
          dancer.moveTo(sX, sY);
          dancer.bezierCurveTo(cX2, cY1, cX1, cY2, fX, fY);
        }
        dancer.stroke();
      }
    }
  }
  
  if (lastTime == null) {
    lastTime = time;
  } else {
    if (time - lastTime > 450) {
      lastTime = time;
      
      if (numElements == null) {
        numElements = 1;
      }

    }
  }
  
  avg = (avg / numElements);
        
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
  
  window.requestAnimationFrame(renderAudio);
}

var WS_URL = "party.fouad.co";

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