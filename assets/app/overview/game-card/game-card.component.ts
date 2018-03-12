import {Component, Input} from '@angular/core';

@Component({
  selector: 'app-game-card',
  templateUrl: './game-card.component.html',
  styleUrls: ['./game-card.component.css']
})
export class GameCardComponent {

  private _game: any;

  @Input()
  set game(game: any) {
    this._game = game;
  }

  get game(): any {
    return this._game;
  }
}