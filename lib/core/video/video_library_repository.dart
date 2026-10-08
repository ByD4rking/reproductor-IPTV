import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VideoLibraryItem {
  const VideoLibraryItem({required this.id, required this.title, required this.url, this.category = 'Vídeos', this.posterUrl});
  final String id;
  final String title;
  final Uri url;
  final String category;
  final Uri? posterUrl;
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'url':url.toString(),'category':category,if(posterUrl!=null)'posterUrl':posterUrl.toString()};
  static VideoLibraryItem? fromJson(Map<String,dynamic> json){final id=json['id'];final title=json['title'];final raw=json['url'];if(id is! String||title is! String||raw is! String)return null;final url=Uri.tryParse(raw);if(url==null||!{'http','https'}.contains(url.scheme))return null;final p=json['posterUrl'];return VideoLibraryItem(id:id,title:title,url:url,category:json['category'] is String?json['category'] as String:'Vídeos',posterUrl:p is String?Uri.tryParse(p):null);}
}

class VideoLibraryRepository {
  static const _key='video_library_v1';
  final SharedPreferencesAsync _preferences=SharedPreferencesAsync();
  Future<List<VideoLibraryItem>> load() async {final raw=await _preferences.getString(_key);if(raw==null||raw.trim().isEmpty)return const [];try{final decoded=jsonDecode(raw);if(decoded is! List)return const [];return decoded.whereType<Map>().map((e)=>VideoLibraryItem.fromJson(Map<String,dynamic>.from(e))).whereType<VideoLibraryItem>().toList(growable:false);}catch(_){return const [];}}
  Future<void> save(List<VideoLibraryItem> items)=>_preferences.setString(_key,jsonEncode(items.map((e)=>e.toJson()).toList(growable:false)));
  Future<void> upsert(VideoLibraryItem item) async {final items=[...await load()];final i=items.indexWhere((e)=>e.id==item.id);if(i>=0){items[i]=item;}else{items.add(item);}await save(items);}
  Future<void> remove(String id) async=>save((await load()).where((e)=>e.id!=id).toList(growable:false));
}
