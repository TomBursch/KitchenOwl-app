import 'dart:convert';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/recipe.dart';
import 'package:kitchenowl/services/api/api_service.dart';

extension ItemApi on ApiService {
  Future<Item?> getItem(Item item) async {
    final res = await get('/item/${item.id}');
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body);
    return Item.fromJson(body);
  }

  Future<List<Recipe>?> getItemRecipes(Item item) async {
    final res = await get('/item/${item.id}/recipes');
    if (res.statusCode != 200) return null;

    final body = List.from(jsonDecode(res.body));
    return body.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<List<Item>?> searchItem(String query) async {
    final res = await get('/item/search?query=$query');
    if (res.statusCode != 200) return null;

    final body = List.from(jsonDecode(res.body));
    return body.map((e) => Item.fromJson(e)).toList();
  }

  Future<bool> deleteItem(Item item) async {
    final res = await delete('/item/${item.id}');
    return res.statusCode == 200;
  }

  Future<bool> updateItem(Item item) async {
    final res = await post('/item/${item.id}', item.toJson());
    return res.statusCode == 200;
  }
}
