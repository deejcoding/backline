'use client'

import { useState, useEffect, useRef } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { Send, ArrowLeft } from 'lucide-react'
import { useAuthStore } from '@/lib/stores/authStore'
import { useConversations, useMessages, useSendMessage, useMarkAsRead, useStartConversation } from '@/lib/hooks/useMessages'
import { useUser } from '@/lib/hooks/useUsers'
import { Avatar, Button, Input } from '@/components/ui'
import { timeAgo } from '@/lib/types'
import clsx from 'clsx'

export default function MessagesPage() {
  const searchParams = useSearchParams()
  const newUserId = searchParams.get('new')

  const { user, profile, isGuestMode } = useAuthStore()
  const isAuthenticated = !!user && !isGuestMode

  const { conversations, isLoading: conversationsLoading } = useConversations(user?.uid)
  const [activeConversationId, setActiveConversationId] = useState<string | null>(null)
  const [showChat, setShowChat] = useState(false)

  const { data: newUser } = useUser(newUserId || '')
  const startConversation = useStartConversation()

  // Handle starting a new conversation
  useEffect(() => {
    if (newUserId && newUser && user && profile) {
      startConversation.mutateAsync({
        currentUID: user.uid,
        currentUsername: profile.username || '',
        otherUID: newUserId,
        otherUsername: newUser.username,
      }).then((conversationId) => {
        setActiveConversationId(conversationId)
        setShowChat(true)
      })
    }
  }, [newUserId, newUser, user, profile])

  if (!isAuthenticated) {
    return (
      <div className="max-w-[1280px] mx-auto px-4 md:px-8 py-12 text-center">
        <p className="font-mono text-muted mb-4">Please sign in to view messages</p>
        <Link href="/login">
          <Button>Sign In</Button>
        </Link>
      </div>
    )
  }

  const activeConversation = conversations.find((c) => c.id === activeConversationId)

  return (
    <div className="max-w-[1280px] mx-auto h-[calc(100vh-65px-72px)] md:h-[calc(100vh-65px)]">
      <div className="flex h-full">
        {/* Conversation List */}
        <div
          className={clsx(
            'w-full md:w-80 border-r border-dim flex flex-col',
            showChat && 'hidden md:flex'
          )}
        >
          <div className="p-4 border-b border-dim">
            <h1 className="font-mono text-lg font-bold uppercase tracking-tight">Messages</h1>
          </div>

          <div className="flex-1 overflow-y-auto">
            {conversationsLoading ? (
              <div className="flex items-center justify-center py-12">
                <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full spinner" />
              </div>
            ) : conversations.length === 0 ? (
              <div className="text-center py-12 px-4">
                <p className="font-mono text-sm text-muted">No messages yet</p>
              </div>
            ) : (
              conversations.map((conversation) => {
                const otherUID = conversation.participants.find((p) => p !== user?.uid) || ''
                const otherUsername = conversation.participantUsernames[otherUID] || 'Unknown'
                const isUnread = conversation.lastMessage &&
                  conversation.lastMessageSenderUID !== user?.uid &&
                  (!conversation.lastReadAt[user?.uid || ''] ||
                   conversation.lastMessageAt > conversation.lastReadAt[user?.uid || ''])

                return (
                  <button
                    key={conversation.id}
                    onClick={() => {
                      setActiveConversationId(conversation.id)
                      setShowChat(true)
                    }}
                    className={clsx(
                      'w-full p-4 border-b border-dim text-left hover:bg-soft transition-colors',
                      activeConversationId === conversation.id && 'bg-soft'
                    )}
                  >
                    <div className="flex items-center gap-3">
                      <Avatar size="md" />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <p className={clsx(
                            'font-mono text-sm truncate',
                            isUnread ? 'text-ink font-semibold' : 'text-ink'
                          )}>
                            @{otherUsername}
                          </p>
                          <span className="font-mono text-[10px] text-muted flex-shrink-0">
                            {timeAgo(conversation.lastMessageAt)}
                          </span>
                        </div>
                        <p className={clsx(
                          'font-mono text-xs truncate',
                          isUnread ? 'text-ink' : 'text-muted'
                        )}>
                          {conversation.lastMessage || 'No messages yet'}
                        </p>
                      </div>
                      {isUnread && (
                        <div className="w-2 h-2 rounded-full bg-accent flex-shrink-0" />
                      )}
                    </div>
                  </button>
                )
              })
            )}
          </div>
        </div>

        {/* Chat View */}
        <div
          className={clsx(
            'flex-1 flex flex-col',
            !showChat && 'hidden md:flex'
          )}
        >
          {activeConversationId && activeConversation ? (
            <ChatView
              conversationId={activeConversationId}
              conversation={activeConversation}
              currentUID={user?.uid || ''}
              onBack={() => setShowChat(false)}
            />
          ) : (
            <div className="flex-1 flex items-center justify-center">
              <p className="font-mono text-sm text-muted">Select a conversation</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function ChatView({
  conversationId,
  conversation,
  currentUID,
  onBack,
}: {
  conversationId: string
  conversation: any
  currentUID: string
  onBack: () => void
}) {
  const { messages, isLoading } = useMessages(conversationId)
  const sendMessage = useSendMessage()
  const markAsRead = useMarkAsRead()
  const [newMessage, setNewMessage] = useState('')
  const messagesEndRef = useRef<HTMLDivElement>(null)

  const otherUID = conversation.participants.find((p: string) => p !== currentUID) || ''
  const otherUsername = conversation.participantUsernames[otherUID] || 'Unknown'

  // Mark as read when opening
  useEffect(() => {
    markAsRead.mutate({ conversationId, uid: currentUID })
  }, [conversationId, currentUID])

  // Scroll to bottom on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSend = async () => {
    if (!newMessage.trim()) return

    await sendMessage.mutateAsync({
      conversationId,
      senderUID: currentUID,
      text: newMessage,
    })

    setNewMessage('')
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  return (
    <>
      {/* Header */}
      <div className="p-4 border-b border-dim flex items-center gap-3">
        <button
          onClick={onBack}
          className="md:hidden text-muted hover:text-ink transition-colors"
        >
          <ArrowLeft size={20} />
        </button>
        <Avatar size="sm" />
        <Link
          href={`/u/${otherUsername}`}
          className="font-mono text-sm text-ink hover:text-accent transition-colors"
        >
          @{otherUsername}
        </Link>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full spinner" />
          </div>
        ) : messages.length === 0 ? (
          <div className="text-center py-12">
            <p className="font-mono text-sm text-muted">Start the conversation!</p>
          </div>
        ) : (
          messages.map((message) => {
            const isSender = message.senderUID === currentUID

            return (
              <div
                key={message.id}
                className={clsx('flex', isSender ? 'justify-end' : 'justify-start')}
              >
                <div
                  className={clsx(
                    'max-w-[75%] px-3 py-2',
                    isSender
                      ? 'bg-accent text-paper'
                      : 'bg-soft border border-dim text-ink'
                  )}
                >
                  <p className="font-mono text-sm whitespace-pre-wrap break-words">
                    {message.text}
                  </p>
                  <p className={clsx(
                    'font-mono text-[10px] mt-1',
                    isSender ? 'text-paper/70' : 'text-muted'
                  )}>
                    {timeAgo(message.sentAt)}
                  </p>
                </div>
              </div>
            )
          })
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-4 border-t border-dim flex gap-2">
        <Input
          value={newMessage}
          onChange={(e) => setNewMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type a message..."
          className="flex-1"
        />
        <Button
          onClick={handleSend}
          disabled={!newMessage.trim() || sendMessage.isPending}
        >
          <Send size={16} />
        </Button>
      </div>
    </>
  )
}
