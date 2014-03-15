import 'dart:typed_data';
import 'dart:html';
import 'dart:web_audio';

CanvasRenderingContext2D dancer = null;
CanvasElement canvas = null;

var audioContext = new AudioContext();
var audioInput = null,
    realAudioInput = null,
    inputPoint = null;

var zeroGain = null,
    analyserNode = null;

int canvasWidth() {
   return window.innerWidth;
}

int canvasHeight() {
  return window.innerHeight;
}

void renderAudio(time) {
  var SPACING = 3;
  var BAR_WIDTH = 1;
  
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

  // Draw rectangle for each frequency bin.
  for (var i = 0; i < numBars; ++i) {
    var magnitude = 0;
    var offset = ( i * multiplier ).floor();
    // gotta sum/average the block, or we miss narrow-bandwidth spikes
    for (var j = 0; j< multiplier; j++)
      magnitude += freqByteData[offset + j];
    
    magnitude = (magnitude / multiplier);
    
    // increase volatility of the bars
    if (magnitude > 0) {
      magnitude += magnitude * 0.5;
    }
    
    var magnitude2 = freqByteData[i * multiplier];
    dancer.fillStyle = "hsl( 240, 100%, 50%)";
    dancer.fillRect(i * SPACING, canvasHeight(), BAR_WIDTH, -magnitude);
  }
  
  window.requestAnimationFrame(renderAudio);
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
  
  window.navigator.getUserMedia(audio: true).then(handleStream);
}