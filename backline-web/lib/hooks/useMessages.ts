import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  collection,
  query,
  where,
  orderBy,
  getDocs,
  doc,
  addDoc,
  updateDoc,
  serverTimestamp,
  Timestamp,
  onSnapshot,
} from 'firebase/firestore'
import { db } from '@/lib/firebase/config'
import type { Conversation, Message } from '@/lib/types'

// Parse conversation document
function parseConversation(doc: any): Conversation {
  const data = doc.data()

  const lastReadAt: Record<string, Date> = {}
  if (data.lastReadAt) {
    for (const [uid, timestamp] of Object.entries(data.lastReadAt)) {
      lastReadAt[uid] = (timestamp as Timestamp)?.toDate() || new Date()
    }
  }

  return {
    id: doc.id,
    participants: data.participants || [],
    participantUsernames: data.participantUsernames || {},
    lastMessage: data.lastMessage || '',
    lastMessageAt: (data.lastMessageAt as Timestamp)?.toDate() || new Date(),
    lastMessageSenderUID: data.lastMessageSenderUID || '',
    lastReadAt,
  }
}

// Parse message document
function parseMessage(doc: any): Message {
  const data = doc.data()
  return {
    id: doc.id,
    senderUID: data.senderUID,
    text: data.text,
    sentAt: (data.sentAt as Timestamp)?.toDate() || new Date(),
  }
}

// Real-time conversations listener
export function useConversations(uid: string | undefined) {
  const [conversations, setConversations] = useState<Conversation[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!uid) {
      setConversations([])
      setIsLoading(false)
      return
    }

    setIsLoading(true)

    const q = query(
      collection(db, 'conversations'),
      where('participants', 'array-contains', uid),
      orderBy('lastMessageAt', 'desc')
    )

    const unsub = onSnapshot(q, (snapshot) => {
      setConversations(snapshot.docs.map(parseConversation))
      setIsLoading(false)
    })

    return () => unsub()
  }, [uid])

  // Get unread count
  const unreadCount = conversations.filter((c) => {
    if (!c.lastMessage || c.lastMessageSenderUID === uid) return false
    const lastRead = c.lastReadAt[uid!]
    if (!lastRead) return true
    return c.lastMessageAt > lastRead
  }).length

  return { conversations, isLoading, unreadCount }
}

// Real-time messages listener
export function useMessages(conversationId: string | undefined) {
  const [messages, setMessages] = useState<Message[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!conversationId) {
      setMessages([])
      setIsLoading(false)
      return
    }

    setIsLoading(true)

    const q = query(
      collection(db, 'conversations', conversationId, 'messages'),
      orderBy('sentAt', 'asc')
    )

    const unsub = onSnapshot(q, (snapshot) => {
      setMessages(snapshot.docs.map(parseMessage))
      setIsLoading(false)
    })

    return () => unsub()
  }, [conversationId])

  return { messages, isLoading }
}

// Start or get existing conversation
export function useStartConversation() {
  return useMutation({
    mutationFn: async ({
      currentUID,
      currentUsername,
      otherUID,
      otherUsername,
      initialMessage,
    }: {
      currentUID: string
      currentUsername: string
      otherUID: string
      otherUsername: string
      initialMessage?: string
    }): Promise<string> => {
      // Check for existing conversation
      const existingQuery = query(
        collection(db, 'conversations'),
        where('participants', 'array-contains', currentUID)
      )
      const existing = await getDocs(existingQuery)

      for (const doc of existing.docs) {
        const data = doc.data()
        if (data.participants?.includes(otherUID)) {
          // Found existing conversation
          if (initialMessage) {
            await sendMessageToConversation(doc.id, currentUID, initialMessage)
          }
          return doc.id
        }
      }

      // Create new conversation
      const conversationRef = await addDoc(collection(db, 'conversations'), {
        participants: [currentUID, otherUID],
        participantUsernames: {
          [currentUID]: currentUsername,
          [otherUID]: otherUsername,
        },
        lastMessage: '',
        lastMessageAt: serverTimestamp(),
        lastMessageSenderUID: '',
        lastReadAt: {
          [currentUID]: serverTimestamp(),
          [otherUID]: serverTimestamp(),
        },
      })

      if (initialMessage) {
        await sendMessageToConversation(conversationRef.id, currentUID, initialMessage)
      }

      return conversationRef.id
    },
  })
}

// Send message
async function sendMessageToConversation(
  conversationId: string,
  senderUID: string,
  text: string
) {
  const trimmedText = text.trim()
  if (!trimmedText) return

  // Add message
  await addDoc(collection(db, 'conversations', conversationId, 'messages'), {
    senderUID,
    text: trimmedText,
    sentAt: serverTimestamp(),
  })

  // Update conversation
  await updateDoc(doc(db, 'conversations', conversationId), {
    lastMessage: trimmedText,
    lastMessageAt: serverTimestamp(),
    lastMessageSenderUID: senderUID,
  })
}

export function useSendMessage() {
  return useMutation({
    mutationFn: async ({
      conversationId,
      senderUID,
      text,
    }: {
      conversationId: string
      senderUID: string
      text: string
    }) => {
      await sendMessageToConversation(conversationId, senderUID, text)
    },
  })
}

// Mark conversation as read
export function useMarkAsRead() {
  return useMutation({
    mutationFn: async ({
      conversationId,
      uid,
    }: {
      conversationId: string
      uid: string
    }) => {
      await updateDoc(doc(db, 'conversations', conversationId), {
        [`lastReadAt.${uid}`]: serverTimestamp(),
      })
    },
  })
}
