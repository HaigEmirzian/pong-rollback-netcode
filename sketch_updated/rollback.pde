import java.util.ArrayList; //<>//
import processing.net.*;

// Networking
Server server;
Client client;

int time = 0;

int ballX, ballY, ballSpeedX, ballSpeedY;
int player1Y, player2Y;
int playerSpeed = 5;
int paddleWidth = 10, paddleHeight = 80;
int ballSize = 20;
boolean isServer = true;  // True if this instance is the server

int input1 = 0;
int input2 = 0;

long startTime = 0;
boolean playing = false;

int framesBack = 5;

// History buffer for rollback
ArrayList<GameState> stateHistory = new ArrayList<GameState>();
ArrayList<Integer> predictedInputs = new ArrayList<Integer>(10000);

// Class to represent the game state at a given frame
class GameState {
  int time;
  boolean confirmed;
  int ballX, ballY;
  int player1Y, player2Y;
  
  GameState(int t, boolean con, int bx, int by, int p1Y, int p2Y) {
    time = t;
    confirmed = con;
    ballX = bx;
    ballY = by;
    player1Y = p1Y;
    player2Y = p2Y;
  }
}

// Called once
void setup() {
  size(640, 480);
  if (isServer) { // Start Server
    server = new Server(this, 5201);
  } else { // Start Client
    client = new Client(this, "127.0.0.1", 5201);
    
    // Wait to receive the start time from the server
    while (client.available() == 0) { continue; }
    startTime = Long.parseLong(client.readString().trim());
  }
  
  // Initalize predictions
  for(int i = 0; i < 100000; i++) {
    predictedInputs.add(0); 
  }
}

// Called when a client connects
void serverEvent(Server someServer, Client someClient) {
  if (isServer) {
    // Send start time to the client
    startTime = System.currentTimeMillis() + 5000;
    server.write(startTime + "\n");
  }
}


// Called every frame
void draw() {
  background(0);
  
  // Wait for the start time before drawing anything
  if (!playing) {
    if (System.currentTimeMillis() < startTime) { // Continue waiting
      println(System.currentTimeMillis() - startTime + "");
      return;
    }
    else if (startTime > 0){ // Start the game
      playing = true;
      time = 0;
      resetGame();
    }
  }
  
  // ----- Retrieve Remote inputs -----
  // Server: read from socket
  if (isServer && server.available() != null) {
    Client thisClient = server.available();
    String data = thisClient.readString();
    if (data != null) {
      //print("Got remote intput: " + data);
      ArrayList<Integer[]> remoteInput = parseInput(data);
      handleRemoteInput(remoteInput);  // Apply remote inputs from client
    }
  }
  // Networking - Client
  else if (!isServer && client.available() > 0) {
    String data = client.readString();
    if (data != null) {
      //println("Got remote intput: " + data);
      ArrayList<Integer[]> remoteInput = parseInput(data);
      handleRemoteInput(remoteInput);  // Apply remote inputs from server
    }
  }
  
  // ----- Get inputs -----
  // Get current player
  if (keyPressed) {
    if (key == 'w') {
      if (isServer) {
        input1 = -1;
      }
      else {
        input2 = -1;
      }
       
      sendLocalInput(time, -1);
    } 
    else if (key == 's') {
      if (isServer) {
        input1 = 1;
      }
      else {
        input2 = 1;
      }
      
      sendLocalInput(time, 1);
    }
  }
  else {
    if (isServer) {
        input1 = 0;
      }
      else {
         input2 = 0; 
      }
      
      sendLocalInput(time, 0);
  }
  
  //println(predictedInputs);
  
  // Get other player
  if (isServer) {
    input2 = predictedInputs.get(time);
  }
  else {
    input1 = predictedInputs.get(time);
  }
  
  // ----- Update Game -----
  updateGame();
  
  // ----- Render -----
  // Draw ball
  ellipse(ballX, ballY, ballSize, ballSize);
  
  // Draw paddles
  rect(30, player1Y, paddleWidth, paddleHeight);
  rect(width - 50, player2Y, paddleWidth, paddleHeight);
}

void rollbackTo(GameState oldState) {
  // Rollback to a previous state
  time = oldState.time;
  ballX = oldState.ballX;
  ballY = oldState.ballY;
  player1Y = oldState.player1Y;
  player2Y = oldState.player2Y;
}

void resetGame() {
  ballX = width / 2;
  ballY = height / 2;
  ballSpeedX = 2;
  ballSpeedY = 2;
  
  player1Y = height / 2 - paddleHeight / 2;
  player2Y = height / 2 - paddleHeight / 2;
}

// Parse input data from remote
ArrayList<Integer[]> parseInput(String data) {
  ArrayList<Integer[]> results = new ArrayList<Integer[]>();
  String[] parts = data.trim().split(",");
  
  for(int i = 0; i * 2 < parts.length - 1; i += 2) {
    results.add(new Integer[] {Integer.parseInt(parts[2*i]), Integer.parseInt(parts[2*i+1])});
  }

  return results;
}

void handleRemoteInput(ArrayList<Integer[]> remoteInputs) {
  for(Integer[] remoteInput : remoteInputs) { //<>//
    int t = remoteInput[0];
    int newInput = remoteInput[1];
    int oldInput = predictedInputs.get(t);
    
    if (oldInput != newInput) {
      predictedInputs.set(remoteInput[0], remoteInput[1]);  
      
      if (t < time) {
          println("rolleback");
         rollbackTo(stateHistory.get(t));
      }
    }
  }
}

// Send local input to remote client/server
void sendLocalInput(int time, int i) {
  String input = time + "," + i + ",";
  if (isServer) {
    server.write(input + "\n");
  } else {
    client.write(input + "\n");
  }
}

void updateGame() {
  // Update ball position
  ballX += ballSpeedX;
  ballY += ballSpeedY;

  if (ballY <= 0 || ballY >= height) {
    ballSpeedY *= -1;
  }
  
//println("1: " + input1 + " 2: " + input2);

  player1Y += playerSpeed * input1;
  player2Y += playerSpeed * input2;
  
  // Ball collision with paddles
  if (ballX <= 40 && ballY > player1Y && ballY < player1Y + paddleHeight) {
    ballSpeedX *= -1;
  }
  
  if (ballX >= width - 40 && ballY > player2Y && ballY < player2Y + paddleHeight) {
    ballSpeedX *= -1;
  }
  
  // Ball outside of screen
  if (ballX < 0 || ballX > width) {
     resetGame(); 
  }
  
  saveGameState();
  time++;
}

void saveGameState() {
  // Save the current game state
  stateHistory.add(new GameState(time, false, ballX, ballY, player1Y, player2Y));


}
