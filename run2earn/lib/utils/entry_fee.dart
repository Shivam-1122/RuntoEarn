double getEntryFee(int min) {
  switch (min) {
    case 1:   // testing
      return 0.01;

    case 10:
      return 0.05;

    case 20:
      return 0.10;

    case 30:
      return 0.50;

    default:
      return 0.0;
  }
}
