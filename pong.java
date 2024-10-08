import java.util.ArrayList;
import processing.net.*;

// Networking
Server server;
Client client;

int ballX, ballY, ballSpeedX, ballSpeedY;
int player1Y, player2Y;
int playerSpeed = 5;
int paddleWidth = 10, paddleHeight = 80;
int ballSize = 20;
boolean isServer = true;  // True if this instance is the server

// History buffer for rollback
ArrayList<GameState> stateHistory = new ArrayList<GameState>();
int maxHistory = 10;  // Keep the last 10 states

void setup() {
  size(640, 480);
  if (isServer) {
    server = new Server(this, 5200);  // Start server on port 5200
  } else {
    client = new Client(this, "127.0.0.1", 5200);  // Connect to localhost server
  }
  resetGame();
}

void resetGame() {
  ballX = width / 2;
  ballY = height / 2;
  ballSpeedX = 4;
  ballSpeedY = 4;
  
  player1Y = height / 2 - paddleHeight / 2;
  player2Y = height / 2 - paddleHeight / 2;
  
  // Initialize game state history
  stateHistory.clear();
  stateHistory.add(new GameState(ballX, ballY, player1Y, player2Y));
}

void draw() {
  background(0);
  
  // Networking - Server
  if (isServer && server.available() != null) {
    Client thisClient = server.available();
    String data = thisClient.readString();
    if (data != null) {
      int[] remoteInputs = parseInput(data);
      handleRemoteInput(remoteInputs);  // Apply remote inputs from client
    }
  }

  // Networking - Client
  if (!isServer && client.available() > 0) {
    String data = client.readString();
    if (data != null) {
      int[] remoteInputs = parseInput(data);
      handleRemoteInput(remoteInputs);  // Apply remote inputs from server
    }
  }
  
  // Display game
  displayGame();
  updateGame();
  saveGameState();
  handleRollback();

  // Send inputs (both clients and server send their local inputs)
  sendLocalInput();
}

void displayGame() {
  // Draw ball
  ellipse(ballX, ballY, ballSize, ballSize);
  
  // Draw paddles
  rect(30, player1Y, paddleWidth, paddleHeight);
  rect(width - 50, player2Y, paddleWidth, paddleHeight);
}

void updateGame() {
  // Update ball position
  ballX += ballSpeedX;
  ballY += ballSpeedY;
  
  if (ballY <= 0 || ballY >= height) {
    ballSpeedY *= -1;
  }
  
  // Paddle movement
  if (keyPressed) {
    if (key == 'w') {
      player1Y -= playerSpeed;
    } else if (key == 's') {
      player1Y += playerSpeed;
    }
    
    if (key == 'o') {
      player2Y -= playerSpeed;
    } else if (key == 'l') {
      player2Y += playerSpeed;
    }
  }
  
  // Ball collision with paddles
  if (ballX <= 40 && ballY > player1Y && ballY < player1Y + paddleHeight) {
    ballSpeedX *= -1;
  }
  
  if (ballX >= width - 40 && ballY > player2Y && ballY < player2Y + paddleHeight) {
    ballSpeedX *= -1;
  }
}

void saveGameState() {
  // Save the current game state
  stateHistory.add(new GameState(ballX, ballY, player1Y, player2Y));
  
  // Keep history size limited
  if (stateHistory.size() > maxHistory) {
    stateHistory.remove(0);
  }
}

void handleRollback() {
  // Simulate detecting an out-of-sync state, rollback every 100 frames for demo
  if (frameCount % 100 == 0) {
    rollbackTo(5);  // Rollback to 5 frames ago
  }
}

void rollbackTo(int framesAgo) {
  // Rollback to a previous state
  int index = stateHistory.size() - 1 - framesAgo;
  if (index >= 0) {
    GameState oldState = stateHistory.get(index);
    ballX = oldState.ballX;
    ballY = oldState.ballY;
    player1Y = oldState.player1Y;
    player2Y = oldState.player2Y;
  }
}

// Send local input to remote client/server
void sendLocalInput() {
  String input = player1Y + "," + player2Y;
  if (isServer) {
    server.write(input + "\n");
  } else {
    client.write(input + "\n");
  }
}

// Parse input data from remote
int[] parseInput(String data) {
  String[] parts = data.trim().split(",");
  int[] inputs = new int[2];
  inputs[0] = int(parts[0]);  // Remote player1Y
  inputs[1] = int(parts[1]);  // Remote player2Y
  return inputs;
}

// Handle remote inputs
void handleRemoteInput(int[] remoteInputs) {
  player1Y = remoteInputs[0];
  player2Y = remoteInputs[1];
}

// Class to represent the game state at a given frame
class GameState {
  int ballX, ballY;
  int player1Y, player2Y;
  
  GameState(int bx, int by, int p1Y, int p2Y) {
    ballX = bx;
    ballY = by;
    player1Y = p1Y;
    player2Y = p2Y;
  }
}
