/// Mechanic Mixins
/// 
/// Auto-generated mixins for game mechanics.
/// These provide reusable behavior patterns.

import 'package:flame/components.dart';
import 'package:flutter/material.dart';


mixin JumpableMixin on PositionComponent {
  double jumpForce = -400;
  double gravity = 800;
  double velocityY = 0;
  bool isGrounded = true;
  
  void jump() {
    if (isGrounded) {
      velocityY = jumpForce;
      isGrounded = false;
    }
  }
  
  void applyGravity(double dt) {
    if (!isGrounded) {
      velocityY += gravity * dt;
      position.y += velocityY * dt;
    }
  }
  
  void land(double groundY) {
    if (position.y >= groundY) {
      position.y = groundY;
      velocityY = 0;
      isGrounded = true;
    }
  }
}

