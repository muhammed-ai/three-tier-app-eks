import { useState, useEffect } from 'react'

function App() {
  const [items, setItems] = useState([])
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Fetch items on mount
  useEffect(() => {
    fetchItems()
  }, [])

  const fetchItems = async () => {
    try {
      setLoading(true)
      const response = await fetch('/api/items')
      if (!response.ok) throw new Error('Failed to fetch items')
      const data = await response.json()
      setItems(data)
      setError(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!name.trim()) return

    try {
      const response = await fetch('/api/items', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, description })
      })
      
      if (!response.ok) throw new Error('Failed to create item')
      
      const newItem = await response.json()
      setItems([newItem, ...items])
      setName('')
      setDescription('')
    } catch (err) {
      setError(err.message)
    }
  }

  const handleDelete = async (id) => {
    try {
      const response = await fetch(`/api/items/${id}`, {
        method: 'DELETE'
      })
      
      if (!response.ok) throw new Error('Failed to delete item')
      
      setItems(items.filter(item => item.id !== id))
    } catch (err) {
      setError(err.message)
    }
  }

  return (
    <div className="app">
      <header>
        <h1>Three Tier App</h1>
        <p>React + Express + MySQL</p>
        <p className="subtitle">
          A sample three-tier application demonstrating containerized deployment on AWS EKS.
          Built with a React frontend, Express backend, and MySQL database — designed for GitOps workflows with environment promotion.
        </p>
      </header>

      {error && <div className="error">{error}</div>}

      <form onSubmit={handleSubmit} className="form">
        <input
          type="text"
          placeholder="Item name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
        />
        <input
          type="text"
          placeholder="Description (optional)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
        <button type="submit">Add Item</button>
      </form>

      {loading ? (
        <p>Loading...</p>
      ) : (
        <ul className="items-list">
          {items.map(item => (
            <li key={item.id}>
              <div>
                <strong>{item.name}</strong>
                {item.description && <span> - {item.description}</span>}
              </div>
              <button onClick={() => handleDelete(item.id)}>Delete</button>
            </li>
          ))}
          {items.length === 0 && <li>No items yet. Add one above!</li>}
        </ul>
      )}
    </div>
  )
}

export default App
