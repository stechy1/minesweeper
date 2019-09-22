import { Drawer } from './drawer';

export class GridPoint {

    private _visualization: string;
    private _value: number | string;
    private _badMine: boolean;

    constructor(private _col: number, private _row: number, private _rawCoordinates: {
        x: number, y: number, topLeft: { x: number, y: number }, topRight: { x: number, y: number }, bottomLeft: { x: number, y: number }, bottomRight: { x: number, y: number }
    }) {
        this._visualization = '';
        this._value = '?';
        this._badMine = false;
    }

    draw(drawer: Drawer): void {
        if (this._value !== '?') {
            drawer.drawText('' + this._value, this._rawCoordinates.x, this._rawCoordinates.y);
        }
    }

    reset(): void {
        this._value = '?';
    }

    badMine(): void {
        this._badMine = true;
    }

    get col(): number {
        return this._col;
    }

    get row(): number {
        return this._row;
    }

    get value(): number | string {
        return this._value;
    }

    set value(value: number | string) {
        this._value = value;
    }

    get isBadMine(): boolean {
        return this._badMine;
    }
}
