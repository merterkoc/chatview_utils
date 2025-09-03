import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/data_models/chat_view_list_item.dart';
import '../values/enumeration.dart';
import '../values/typedefs.dart';
import 'auto_animated_sliver_list_controller.dart';

base class ChatViewListController {
  ChatViewListController({
    required List<ChatViewListItem> initialChatList,
    required this.scrollController,
    bool disposeOtherResources = true,
    bool sortEnable = true,
    ChatSorter? chatSorter,
  }) : _disposeOtherResources = disposeOtherResources {
    _animatedListController = AutoAnimateSliverListController<ChatViewListItem>(
      items: initialChatList,
      itemKeyExtractor: (item) => item.id,
    );

    chatListStream = _chatListStreamController.stream.map(
      (chatMap) {
        final chatList = chatMap.values.toList();
        if (sortEnable) {
          chatList.sort(
            chatSorter ?? ChatViewListSortBy.pinFirstByPinTime.sort,
          );
        }
        return chatList;
      },
    );

    final chatListLength = initialChatList.length;

    final chatsMap = {
      for (var i = 0; i < chatListLength; i++)
        if (initialChatList[i] case final chat) chat.id: chat,
    };

    chatListMap
      ..clear()
      ..addAll(chatsMap);

    // Adds the current chat map to the stream controller
    // after the first frame render.
    Future.delayed(
      Duration.zero,
      () => _chatListStreamController.add(chatListMap),
    );
  }

  late final AutoAnimateSliverListController<ChatViewListItem>
      _animatedListController;

  AutoAnimateSliverListController<ChatViewListItem>
      get animatedListController => _animatedListController;

  /// Stores and manages chat items by their unique IDs.
  /// A map is used for efficient lookup, update, and removal of chats
  /// by their unique id.
  final chatListMap = <String, ChatViewListItem>{};
  Map<String, ChatViewListItem>? _searchResultMap;

  /// Provides scroll controller for chat list.
  final ScrollController scrollController;

  final bool _disposeOtherResources;

  bool get isSearching => _searchResultMap != null;

  /// Stream controller to manage the chat list stream.
  final StreamController<Map<String, ChatViewListItem>>
      _chatListStreamController =
      StreamController<Map<String, ChatViewListItem>>.broadcast();

  late final Stream<List<ChatViewListItem>> chatListStream;

  /// Adds a chat to the chat list.
  void addChat(ChatViewListItem chat) {
    chatListMap[chat.id] = chat;
    if (_chatListStreamController.isClosed || _searchResultMap != null) return;
    _chatListStreamController.add(chatListMap);
    _animatedListController.addItem(
      chat,
      isPinned: (item) => item.settings.pinStatus.isPinned,
    );
  }

  /// Function for loading data while pagination.
  void loadMoreChats(List<ChatViewListItem> chatList) {
    final chatListLength = chatList.length;
    chatListMap.addAll(
      {
        for (var i = 0; i < chatListLength; i++)
          if (chatList[i] case final chat) chat.id: chat,
      },
    );
    if (_chatListStreamController.isClosed) return;
    _chatListStreamController.add(chatListMap);
  }

  /// Updates the chat entry in [chatListMap] for the given [chatId] using
  /// the provided [newChat] callback.
  ///
  /// If the chat with [chatId] does not exist, the method returns without
  /// making changes.
  void updateChat(String chatId, UpdateChatCallback newChat) {
    var isSearchUpdated = false;
    if (_searchResultMap?[chatId] case final searchChat?) {
      final updatedChat = newChat(searchChat);
      _searchResultMap?[chatId] = updatedChat;
      isSearchUpdated = true;
    }

    final chat = chatListMap[chatId];
    if (!isSearchUpdated && chat == null) return;

    if (chat != null) {
      chatListMap[chatId] = _searchResultMap?[chatId] ?? newChat(chat);
    }

    if (_chatListStreamController.isClosed) return;
    _chatListStreamController.add(_searchResultMap ?? chatListMap);
  }

  /// Removes the chat with the given [chatId] from the chat list.
  ///
  /// If the chat with [chatId] does not exist, the method returns without
  /// making changes.
  void removeChat(String chatId) {
    _searchResultMap?.remove(chatId);
    if (!chatListMap.containsKey(chatId)) return;
    chatListMap.remove(chatId);
    _animatedListController.removeItem(chatId);

    if (_chatListStreamController.isClosed) return;
    _chatListStreamController.add(_searchResultMap ?? chatListMap);
  }

  /// Adds the given chat search results to the stream after the current frame.
  void setSearchChats(List<ChatViewListItem> searchResults) {
    final searchResultLength = searchResults.length;
    _searchResultMap = {
      for (var i = 0; i < searchResultLength; i++)
        if (searchResults[i] case final chat) chat.id: chat,
    };
    if (_chatListStreamController.isClosed) return;
    _chatListStreamController.add(_searchResultMap ?? chatListMap);
  }

  /// Function to clear the search results and show the original chat list.
  void clearSearch() {
    _searchResultMap?.clear();
    _searchResultMap = null;
    if (_chatListStreamController.isClosed) return;
    _chatListStreamController.add(chatListMap);
  }

  /// Used to dispose ValueNotifiers and Streams.
  ///
  /// If [disposeOtherResources] is true, it will also dispose the
  /// scroll controller and text editing controller if provided.
  void dispose() {
    _chatListStreamController.close();
    _animatedListController.dispose();
    if (_disposeOtherResources) {
      scrollController.dispose();
    }
  }
}
