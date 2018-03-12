import { Drawer } from './drawer';

export class GridPoint {

  private _borders: Array<number>;
  private _visualization: string;
  private _value: number;

  constructor(private _col: number, private _row: number, private _rawCoordinates: {
      x: number, y: number
      , topLeft: { x: number, y: number }
      , topRight: { x: number, y: number }
      , bottomLeft: { x: number, y: number }
      , bottomRight: { x: number, y: number }
    }) {
    this._borders = [];
    this._visualization = '';
    this._value = -1;
  }
  draw(drawer: Drawer): void {
    drawer.drawLine(this._rawCoordinates.topLeft, this._rawCoordinates.bottomRight);
    drawer.drawLine(this._rawCoordinates.bottomLeft, this._rawCoordinates.topRight);
  }

  clearBorders(): void {
    this._borders = [];
  }

  reset(): void {
    this.clearBorders();
    this._value = -1;
  }

  togglePoint(): void {
    this._value *= -1;
    console.log("Toggle to: " + this._value);
  }

  setPoint(): void {
    this._value = 1;
  }

  get borders(): Array<number> {
    return this._borders;
  }

  set borders(value: Array<number>) {
    this._borders = value;
  }

  get col(): number {
    return this._col;
  }

  get row(): number {
    return this._row;
  }

  get value(): number {
    return this._value;
  }
}
