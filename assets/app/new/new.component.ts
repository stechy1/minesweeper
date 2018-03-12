import { Component } from '@angular/core';

@Component({
  selector: 'app-new',
  templateUrl: './new.component.html',
  styleUrls: ['./new.component.css']
})
export class NewComponent {

  public configuration: GameConfiguration = new GameConfiguration();
  public gameTypes = [
    'Začátečník',
    'Pokročilý',
    'Expert',
    'Vlastní',
  ];
  public radioChanged: boolean = false;

  private _selectedGameType: number = 0;

  get selectedGameType(): number {
    return this._selectedGameType;
  }

  set selectedGameType(value: number) {
    this._selectedGameType = value;
    this.radioChanged = true;
  }
}

class GameConfiguration {
  private _cols: number = 0;
  private _rows: number = 0;
  private _mines: number = 0;


  get cols(): number {
    return this._cols;
  }

  set cols(value: number) {
    this._cols = value;
  }

  get rows(): number {
    return this._rows;
  }

  set rows(value: number) {
    this._rows = value;
  }

  get mines(): number {
    return this._mines;
  }

  set mines(value: number) {
    this._mines = value;
  }
}