enum FacingDirection {
  left,
  right;

  double get scaleX => this == FacingDirection.right ? 1.0 : -1.0;
}
